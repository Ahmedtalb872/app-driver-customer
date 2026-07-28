// Supabase Auth "Send SMS" hook: invoked by Supabase Auth (not by the app
// directly) every time `signInWithOtp`/phone sign-up needs to deliver a
// code, in place of a built-in provider (Twilio/MessageBird/...) which
// Chinguisoft isn't. Supabase generates the OTP; this function's only job
// is handing it to Chinguisoft's SMS validation API for actual delivery.
// See: https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook
//
// Configure after deploying (`supabase functions deploy send-sms-hook`):
//   1. Secrets (Project Settings -> Edge Functions, or `supabase secrets set`):
//        CHINGUISOFT_VALIDATION_KEY   - the validation_key from chinguisoft.com/sn
//        CHINGUISOFT_VALIDATION_TOKEN - the matching Validation-token
//   2. Authentication -> Hooks -> "Send SMS hook" -> point at this
//      function's URL; Supabase generates SEND_SMS_HOOK_SECRET itself and
//      injects it as an env var automatically once the hook is enabled.
import { Webhook } from 'https://esm.sh/standardwebhooks@1.0.0';

interface SendSmsPayload {
  user: { phone?: string };
  sms: { otp: string };
}

/// Chinguisoft expects a local 8-digit number (e.g. "44800028"), not the
/// E.164 format Supabase stores (e.g. "+22244800028").
function toLocalMauritanianNumber(phone: string): string {
  return phone.replace(/^\+?222/, '');
}

Deno.serve(async (req) => {
  const payload = await req.text();
  const headers = Object.fromEntries(req.headers);

  const hookSecret = Deno.env.get('SEND_SMS_HOOK_SECRET') ?? '';
  const base64Secret = hookSecret.replace('v1,whsec_', '');
  const wh = new Webhook(base64Secret);

  let user: SendSmsPayload['user'];
  let sms: SendSmsPayload['sms'];
  try {
    ({ user, sms } = wh.verify(payload, headers) as SendSmsPayload);
  } catch (error) {
    return new Response(
      JSON.stringify({ error: { http_code: 401, message: `Invalid webhook signature: ${error}` } }),
      { status: 401 },
    );
  }

  if (!user.phone) {
    return new Response(
      JSON.stringify({ error: { http_code: 400, message: 'Missing user phone number.' } }),
      { status: 400 },
    );
  }

  const validationKey = Deno.env.get('CHINGUISOFT_VALIDATION_KEY');
  const validationToken = Deno.env.get('CHINGUISOFT_VALIDATION_TOKEN');
  if (!validationKey || !validationToken) {
    return new Response(
      JSON.stringify({
        error: { http_code: 500, message: 'Chinguisoft credentials are not configured.' },
      }),
      { status: 500 },
    );
  }

  try {
    const response = await fetch(
      `https://chinguisoft.com/api/sms/validation/${validationKey}`,
      {
        method: 'POST',
        headers: {
          'Validation-token': validationToken,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          phone: toLocalMauritanianNumber(user.phone),
          lang: 'ar',
          code: sms.otp,
        }),
      },
    );

    if (!response.ok) {
      const body = await response.text();
      return new Response(
        JSON.stringify({
          error: {
            http_code: 502,
            message: `Chinguisoft rejected the SMS request (${response.status}): ${body}`,
          },
        }),
        { status: 502 },
      );
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ error: { http_code: 502, message: `Failed to reach Chinguisoft: ${error}` } }),
      { status: 502 },
    );
  }

  return new Response(JSON.stringify({}), { status: 200 });
});
