// Mints short-lived Cloudflare Realtime TURN credentials for one in-app
// call - see CallService._buildIceServers (lib/core/services/call_service.dart),
// which calls this right before creating the RTCPeerConnection. The app
// has been STUN-only (Google's public servers) up to now, which can't
// cross a strict/symmetric NAT on either side; TURN relays the media
// through Cloudflare's network instead when a direct path can't be found.
// Falls back to STUN-only exactly as before whenever this isn't
// configured or the Cloudflare request fails - a broken/missing TURN
// setup must never be the reason a call stops working.
//
// Required secrets (Cloudflare dashboard: Realtime > TURN Server > Create
// - see https://developers.cloudflare.com/realtime/turn/):
//   CLOUDFLARE_TURN_KEY_ID      the "معرف رمز التحويل" / Turn Token ID
//   CLOUDFLARE_TURN_API_TOKEN   the "رمز API" / API Token shown once at
//     creation time - Cloudflare does not show it again afterward.
//
// Called by any signed-in user (customer, captain or admin all place
// calls) - gated to a valid session only, same posture as
// voice-transcribe/places-search, so Cloudflare's free-tier usage can't be
// spent by an unauthenticated caller.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CLOUDFLARE_TURN_KEY_ID = Deno.env.get("CLOUDFLARE_TURN_KEY_ID") ?? "";
const CLOUDFLARE_TURN_API_TOKEN = Deno.env.get("CLOUDFLARE_TURN_API_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData?.user) return json({ error: "unauthorized" }, 401);

  // Not configured yet - the client treats a null iceServers exactly like
  // a fetch failure and just keeps using its own STUN-only fallback.
  if (!CLOUDFLARE_TURN_KEY_ID || !CLOUDFLARE_TURN_API_TOKEN) {
    return json({ iceServers: null });
  }

  try {
    // 1 hour - comfortably longer than any real call, short enough that a
    // leaked credential (these are returned to the client) stops being
    // useful quickly. Cloudflare allows up to 48h; there's no reason to
    // ask for anywhere near that here.
    const response = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${CLOUDFLARE_TURN_KEY_ID}/credentials/generate`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${CLOUDFLARE_TURN_API_TOKEN}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ ttl: 3600 }),
      },
    );
    const data = await response.json();

    if (!response.ok) {
      console.error(
        `turn-credentials: HTTP ${response.status} from Cloudflare - ${JSON.stringify(data)}`,
      );
      return json({ iceServers: null });
    }

    return json({ iceServers: data.iceServers ?? null });
  } catch (e) {
    console.error("turn-credentials: exception", e);
    return json({ iceServers: null });
  }
});
