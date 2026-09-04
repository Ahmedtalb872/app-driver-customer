// Sends a real FCM *notification* (not data-only) to every customer and/or
// captain with a saved fcm_token, so the OS shows it in the system tray
// even if the app is backgrounded or fully killed - no custom Dart
// background handler needed on the client for this, unlike
// send-trip-push's data-only new-trip alert (which needs custom
// ringing/full-screen logic).
//
// `audience` in the request body picks who gets it: "customers" (default,
// public.customers.fcm_token), "captains" (public.captains.fcm_token - the
// same column send-trip-push already reads for new-trip alerts, mirrored
// onto customers by 20260817000080_customer_push_broadcasts.sql), or
// "both".
//
// Called directly from the admin dashboard (an authenticated admin
// session), not from a Postgres trigger - so this checks the caller's own
// JWT + public.is_admin() instead of a shared-secret header.
//
// Required secrets:
//   FIREBASE_SERVICE_ACCOUNT_JSON  same one send-trip-push already uses -
//     works for any app registered under that same Firebase project, so
//     no new secret is needed here, only registering the customer app's
//     Android app under that project (see PushNotifications in the
//     Flutter client for what that unlocks).
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are
// provided automatically.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://esm.sh/jose@5";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT_JSON =
  Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";

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

// Cached in module scope so a warm Edge Function instance reuses the same
// access token across invocations instead of round-tripping to Google's
// token endpoint on every single push.
let cachedAccessToken: { token: string; expiresAt: number } | null = null;

async function getFcmAccessToken(): Promise<string> {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.token;
  }
  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);
  const privateKey = await jose.importPKCS8(serviceAccount.private_key, "RS256");
  const jwt = await new jose.SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256" })
    .setIssuedAt()
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setExpirationTime("1h")
    .sign(privateKey);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = await res.json();
  if (!data?.access_token) throw new Error("fcm_auth_failed");
  cachedAccessToken = {
    token: data.access_token,
    expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000,
  };
  return cachedAccessToken.token;
}

async function sendPush(
  deviceToken: string,
  projectId: string,
  title: string,
  body: string,
) {
  const accessToken = await getFcmAccessToken();
  return fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          android: { priority: "high" },
        },
      }),
    },
  );
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    if (!FIREBASE_SERVICE_ACCOUNT_JSON) {
      return json({ error: "firebase_not_configured" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData?.user) return json({ error: "unauthorized" }, 401);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: isAdmin } = await supabase.rpc("is_admin_uid", {
      p_uid: userData.user.id,
    });
    if (!isAdmin) return json({ error: "forbidden" }, 403);

    const { title, body, audience: rawAudience } = await req.json();
    if (!title || !body) return json({ error: "missing_title_or_body" }, 400);
    const audience = ["customers", "captains", "both"].includes(rawAudience)
      ? rawAudience
      : "customers";

    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);
    const tokens: string[] = [];

    if (audience === "customers" || audience === "both") {
      const { data: customers, error: customersError } = await supabase
        .from("customers")
        .select("id, fcm_token")
        .not("fcm_token", "is", null);
      if (customersError) return json({ error: customersError.message }, 500);
      tokens.push(...(customers ?? []).map((c) => c.fcm_token as string).filter(Boolean));
    }

    if (audience === "captains" || audience === "both") {
      const { data: captains, error: captainsError } = await supabase
        .from("captains")
        .select("id, fcm_token")
        .not("fcm_token", "is", null);
      if (captainsError) return json({ error: captainsError.message }, 500);
      tokens.push(...(captains ?? []).map((c) => c.fcm_token as string).filter(Boolean));
    }

    const results = await Promise.allSettled(
      tokens.map((token) => sendPush(token, serviceAccount.project_id, title, body)),
    );
    const sent = results.filter((r) => r.status === "fulfilled").length;

    await supabase.from("notification_broadcasts").insert({
      title,
      body,
      audience,
      recipient_count: sent,
      sent_by: userData.user.id,
    });

    return json({ sent });
  } catch (_e) {
    return json({ error: "internal_error" }, 500);
  }
});
