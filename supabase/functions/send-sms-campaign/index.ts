// Sends a real promotional SMS (a link + discount code - Chinguisoft's
// fixed "SMS Campaign" template, see chinguisoft.com/sn) either to every
// registered customer/captain with a phone number, or to an arbitrary
// admin-pasted phone list (audience "custom") - the latter is the actual
// primary use case: recruiting captains who have never signed up, so
// public.profiles has no row for them at all. Mirrors
// send-broadcast-push's audience/auth shape, but calls Chinguisoft's
// campaign API once per recipient - that API takes a single phone number
// per call, there is no bulk endpoint.
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

/// Chinguisoft expects a local 8-digit number (e.g. "44800028"), not the
/// E.164 format Supabase stores (e.g. "+22244800028"). Strips every
/// non-digit character first (spaces, dashes, parentheses, '+') rather than
/// just the same fixed "+222" prefix send-sms-hook strips, since a
/// "custom" audience is a raw admin-pasted list that can come in almost
/// any punctuation/format.
function toLocalMauritanianNumber(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  return digits.replace(/^222/, "");
}

function sendCampaignSms(
  phone: string,
  url: string,
  code: string,
  reference: number,
) {
  // url/code are sent as empty strings rather than omitted when the caller
  // has none - this campaign account's actual message text is configured
  // on Chinguisoft's own side (Campaign settings), not composed per call;
  // these two fields only ever add an optional link/discount code on top
  // of it.
  return fetch(
    `https://chinguisoft.com/sn/api/sms/campaign/${CHINGUISOFT_CAMPAIGN_KEY}`,
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
        reference,
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
    } = await req.json();
    if (!title) {
      return json({ error: "missing_title" }, 400);
    }
    const url = typeof rawUrl === "string" ? rawUrl : "";
    const code = typeof rawCode === "string" ? rawCode : "";
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
        ...rawPhones.filter((p): p is string => typeof p === "string" && p.trim() !== ""),
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

    const results = await Promise.allSettled(
      phones.map((phone, index) => sendCampaignSms(phone, url, code, index)),
    );
    const sent = results.filter(
      (r) => r.status === "fulfilled" && r.value.ok,
    ).length;

    await supabase.from("sms_campaign_broadcasts").insert({
      title,
      promo_url: url,
      promo_code: code,
      audience,
      recipient_count: sent,
      sent_by: userData.user.id,
    });

    return json({ sent, total: phones.length });
  } catch (_e) {
    return json({ error: "internal_error" }, 500);
  }
});
