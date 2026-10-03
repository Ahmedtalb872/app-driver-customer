// Sends an SMS campaign either to every registered customer/captain with a
// phone number, or to an arbitrary admin-pasted phone list (audience
// "custom") - the latter is the actual primary use case: recruiting
// captains who have never signed up, so public.profiles has no row for
// them at all.
//
// Chinguisoft's campaign API takes a single phone number per call, with no
// bulk endpoint, and this account's own message text is fixed on
// Chinguisoft's side (not composed here - url/code are optional extras on
// top of it). Sends are made *sequentially*, with an admin-configurable
// delay between each (to avoid tripping Chinguisoft's own rate limiting),
// and each recipient's outcome is written to
// public.sms_campaign_recipients immediately as it happens - not batched
// at the end - so a large list (dozens to low hundreds of numbers) surives
// this single Edge Function invocation running out of wall-clock time
// partway through. To keep any one invocation safely inside that time
// budget, at most MAX_PER_INVOCATION pending recipients are processed per
// call; pass the same `campaignId` back in a follow-up call to keep going
// where the previous one left off. The admin dashboard's repository loops
// this automatically until nothing is left pending.
//
// Called directly from the admin dashboard (an authenticated admin
// session), not from a Postgres trigger - so this checks the caller's own
// JWT + public.is_admin_uid() instead of a shared-secret header.
//
// Required secrets (Edge Functions -> Secrets):
//   CHINGUISOFT_CAMPAIGN_KEY    the {campaign_key} path segment shown on
//                               the relevant campaign in chinguisoft.com/sn
//   CHINGUISOFT_CAMPAIGN_TOKEN  that same campaign's "Campaign-token"
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are
// provided automatically.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CHINGUISOFT_CAMPAIGN_KEY = Deno.env.get("CHINGUISOFT_CAMPAIGN_KEY") ?? "";
const CHINGUISOFT_CAMPAIGN_TOKEN =
  Deno.env.get("CHINGUISOFT_CAMPAIGN_TOKEN") ?? "";

// Conservative chunk size: even at the max allowed 3s delay, 50 recipients
// is at most ~150s plus per-request latency - safely inside every Supabase
// Edge Function plan's wall-clock limit.
const MAX_PER_INVOCATION = 50;
const MAX_DELAY_SECONDS = 3;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/// Chinguisoft expects a local 8-digit number (e.g. "44800028"), not the
/// E.164 format Supabase stores (e.g. "+22244800028"). Strips every
/// non-digit character first (spaces, dashes, parentheses, '+') rather than
/// just a fixed "+222" prefix, since a "custom" audience is a raw
/// admin-pasted list that can come in almost any punctuation/format.
function toLocalMauritanianNumber(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  return digits.replace(/^222/, "");
}

async function sendCampaignSms(phone: string, url: string, code: string) {
  return fetch(
    `https://chinguisoft.com/api/sms/campaign/${CHINGUISOFT_CAMPAIGN_KEY}`,
    {
      method: "POST",
      headers: {
        "Campaign-token": CHINGUISOFT_CAMPAIGN_TOKEN,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        phone: toLocalMauritanianNumber(phone),
        lang: "ar",
        url,
        code,
        // Must match an actual pre-written message template's reference
        // number configured on Chinguisoft's own campaign dashboard (this
        // account's only template is reference 1, in ar/fr) - an
        // unmatched reference sends nothing even though the call succeeds.
        reference: 1,
      }),
    },
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!CHINGUISOFT_CAMPAIGN_KEY || !CHINGUISOFT_CAMPAIGN_TOKEN) {
      return json({ error: "chinguisoft_campaign_not_configured" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } =
      await callerClient.auth.getUser();
    if (userError || !userData?.user) return json({ error: "unauthorized" }, 401);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: isAdmin } = await supabase.rpc("is_admin_uid", {
      p_uid: userData.user.id,
    });
    if (!isAdmin) return json({ error: "forbidden" }, 403);

    const {
      title,
      url: rawUrl,
      code: rawCode,
      audience: rawAudience,
      phones: rawPhones,
      campaignId: rawCampaignId,
      delaySeconds: rawDelaySeconds,
    } = await req.json();

    const url = typeof rawUrl === "string" ? rawUrl : "";
    const code = typeof rawCode === "string" ? rawCode : "";
    const delaySeconds = Math.min(
      Math.max(Number(rawDelaySeconds) || 0, 0),
      MAX_DELAY_SECONDS,
    );

    let campaignId: string;

    if (typeof rawCampaignId === "string" && rawCampaignId) {
      // Resuming a campaign started by a previous call - just keep sending
      // to whatever's still pending, no new campaign/recipient rows.
      campaignId = rawCampaignId;
    } else {
      // Starting a brand new campaign.
      if (!title) return json({ error: "missing_title" }, 400);
      const audience = ["customers", "captains", "both", "custom"].includes(
        rawAudience,
      )
        ? rawAudience
        : "custom";

      const phones: string[] = [];

      if (audience === "custom") {
        if (!Array.isArray(rawPhones) || rawPhones.length === 0) {
          return json({ error: "missing_phones" }, 400);
        }
        phones.push(
          ...rawPhones.filter(
            (p): p is string => typeof p === "string" && p.trim() !== "",
          ),
        );
      } else {
        if (audience === "customers" || audience === "both") {
          const { data: customers, error: customersError } = await supabase
            .from("profiles")
            .select("phone")
            .eq("role", "customer")
            .not("phone", "is", null);
          if (customersError) return json({ error: customersError.message }, 500);
          phones.push(
            ...(customers ?? []).map((c) => c.phone as string).filter(Boolean),
          );
        }

        if (audience === "captains" || audience === "both") {
          const { data: captains, error: captainsError } = await supabase
            .from("profiles")
            .select("phone")
            .eq("role", "captain")
            .not("phone", "is", null);
          if (captainsError) return json({ error: captainsError.message }, 500);
          phones.push(
            ...(captains ?? []).map((c) => c.phone as string).filter(Boolean),
          );
        }
      }

      const { data: campaign, error: campaignError } = await supabase
        .from("sms_campaign_broadcasts")
        .insert({
          title,
          promo_url: url,
          promo_code: code,
          audience,
          recipient_count: 0,
          sent_by: userData.user.id,
        })
        .select("id")
        .single();
      if (campaignError || !campaign) {
        return json({ error: campaignError?.message ?? "campaign_create_failed" }, 500);
      }
      campaignId = campaign.id as string;

      const { error: recipientsError } = await supabase
        .from("sms_campaign_recipients")
        .insert(phones.map((phone) => ({ campaign_id: campaignId, phone })));
      if (recipientsError) {
        return json({ error: recipientsError.message }, 500);
      }
    }

    const { data: pending, error: pendingError } = await supabase
      .from("sms_campaign_recipients")
      .select("id, phone")
      .eq("campaign_id", campaignId)
      .eq("status", "pending")
      .order("created_at")
      .limit(MAX_PER_INVOCATION);
    if (pendingError) return json({ error: pendingError.message }, 500);

    let sentThisCall = 0;
    let failedThisCall = 0;

    for (let i = 0; i < (pending ?? []).length; i++) {
      const recipient = pending![i];
      let httpStatus: number | null = null;
      let ok = false;
      let errorMessage: string | null = null;
      try {
        const response = await sendCampaignSms(recipient.phone, url, code);
        httpStatus = response.status;
        ok = response.ok;
        if (!ok) errorMessage = await response.text();
      } catch (e) {
        errorMessage = String(e);
      }

      await supabase
        .from("sms_campaign_recipients")
        .update({
          status: ok ? "sent" : "failed",
          http_status: httpStatus,
          error_message: errorMessage,
          sent_at: new Date().toISOString(),
        })
        .eq("id", recipient.id);

      if (ok) sentThisCall++;
      else failedThisCall++;

      if (i < pending!.length - 1 && delaySeconds > 0) {
        await sleep(delaySeconds * 1000);
      }
    }

    const { count: sentTotal } = await supabase
      .from("sms_campaign_recipients")
      .select("id", { count: "exact", head: true })
      .eq("campaign_id", campaignId)
      .eq("status", "sent");
    const { count: remaining } = await supabase
      .from("sms_campaign_recipients")
      .select("id", { count: "exact", head: true })
      .eq("campaign_id", campaignId)
      .eq("status", "pending");

    await supabase
      .from("sms_campaign_broadcasts")
      .update({ recipient_count: sentTotal ?? 0 })
      .eq("id", campaignId);

    return json({
      campaignId,
      sentThisCall,
      failedThisCall,
      sent: sentTotal ?? 0,
      remaining: remaining ?? 0,
    });
  } catch (_e) {
    return json({ error: "internal_error" }, 500);
  }
});
