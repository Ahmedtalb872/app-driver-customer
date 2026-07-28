// Supabase Auth "Send SMS" hook: invoked by Supabase Auth (not by the app
// directly) every time `signInWithOtp`/phone sign-up needs to deliver a
// code, in place of a built-in provider (Twilio/MessageBird/...) which
// Chinguisoft isn't. Supabase generates the OTP; this function's only job
// is handing it to Chinguisoft's SMS validation API for actual delivery.
// See: https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook
//
// Signature verification is implemented locally (Standard Webhooks: HMAC
// SHA-256 over "{id}.{timestamp}.{payload}") instead of importing the
// `standardwebhooks` package from esm.sh, which repeatedly crashed this
// function's boot (every invocation returned Supabase's generic
// EDGE_FUNCTION_ERROR) - very likely that external module failing to
// resolve inside the edge runtime. Zero external imports now.
//
// Configure after deploying:
//   1. Secrets (Edge Functions -> Secrets):
//        CHINGUISOFT_VALIDATION_KEY   - the validation_key from chinguisoft.com/sn
//        CHINGUISOFT_VALIDATION_TOKEN - the matching Validation-token
//   2. Authentication -> Hooks -> "Send SMS hook" -> HTTPS -> this
//      function's URL, with the "Generate secret" value saved as the
//      SEND_SMS_HOOK_SECRET Edge Function secret (same value, both places).

interface SendSmsPayload {
  user: { phone?: string };
  sms: { otp: string };
}

/// Chinguisoft expects a local 8-digit number (e.g. "44800028"), not the
/// E.164 format Supabase stores (e.g. "+22244800028").
function toLocalMauritanianNumber(phone: string): string {
  return phone.replace(/^\+?222/, '');
}

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function bytesToBase64(bytes: ArrayBuffer): string {
  let binary = '';
  for (const byte of new Uint8Array(bytes)) binary += String.fromCharCode(byte);
  return btoa(binary);
}

/// Verifies a Standard Webhooks-signed request (what Supabase Auth Hooks
/// use) and returns the parsed JSON payload. Throws on any mismatch.
/// See https://www.standardwebhooks.com/ for the spec this implements.
async function verifyWebhook(
  payload: string,
  headers: Record<string, string>,
  hookSecret: string,
): Promise<SendSmsPayload> {
  const id = headers['webhook-id'];
  const timestamp = headers['webhook-timestamp'];
  const signatureHeader = headers['webhook-signature'];
  if (!id || !timestamp || !signatureHeader) {
    throw new Error('Missing webhook-id/webhook-timestamp/webhook-signature headers.');
  }

  const secretBytes = base64ToBytes(hookSecret.replace(/^v1,whsec_/, ''));
  const key = await crypto.subtle.importKey(
    'raw',
    secretBytes,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signedContent = `${id}.${timestamp}.${payload}`;
  const signatureBytes = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signedContent));
  const expectedSignature = bytesToBase64(signatureBytes);

  const providedSignatures = signatureHeader
    .split(' ')
    .map((part) => part.split(',')[1])
    .filter(Boolean);
  if (!providedSignatures.includes(expectedSignature)) {
    throw new Error('Signature mismatch.');
  }

  return JSON.parse(payload) as SendSmsPayload;
}

Deno.serve(async (req) => {
  const payload = await req.text();
  const headers = Object.fromEntries(req.headers);

  const hookSecret = Deno.env.get('SEND_SMS_HOOK_SECRET') ?? '';
  if (!hookSecret) {
    return new Response(
      JSON.stringify({ error: { http_code: 500, message: 'SEND_SMS_HOOK_SECRET is not configured.' } }),
      { status: 500 },
    );
  }

  let user: SendSmsPayload['user'];
  let sms: SendSmsPayload['sms'];
  try {
    ({ user, sms } = await verifyWebhook(payload, headers, hookSecret));
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
