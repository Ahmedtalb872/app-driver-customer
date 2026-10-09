// Live Bankily B-PAY merchant payment call for the customer app, kept
// server-side so the merchant credentials (username/password/client_id)
// and the customer's Bpay passcode never pass through - or live inside -
// the Flutter client.
//
// This is the customer-app counterpart of aihoudhoud (captain app)'s own
// bpay-payment Edge Function - same Bankily merchant API, same request/
// response shape, same BPAY_* secrets (already configured project-wide,
// nothing new to set) - but crediting this app's own public.wallets via
// credit_wallet_from_bpay (20260910000095_customer_bpay_wallet_credit.sql)
// instead of aihoudhoud's captain-only profiles.wallet_balance. Kept as
// its own separately-named function rather than reusing "bpay-payment":
// a single shared Supabase project can only have one function of a given
// name, and the two apps deploy from separate repos, so reusing the name
// would mean whichever repo deploys last silently overwrites the other's
// wallet-crediting logic.
//
// Called from WalletRepository.submitBpayRecharge() via
// supabase.functions.invoke('customer-bpay-payment', ...), authenticated
// with the caller's own Supabase session (their access token is forwarded
// automatically).
//
// Required secrets (already set for aihoudhoud's bpay-payment function -
// project-wide, not per-function, so nothing new to configure here):
//   BPAY_BASE_URL   e.g. https://ebankily-tst.appspot.com (test) or the
//                   production URL Bankily provides after validation
//   BPAY_USERNAME, BPAY_PASSWORD, BPAY_CLIENT_ID  merchant credentials
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically by
// the Edge Functions runtime.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const BPAY_BASE_URL = Deno.env.get("BPAY_BASE_URL") ?? "https://ebankily-tst.appspot.com";
const BPAY_USERNAME = Deno.env.get("BPAY_USERNAME") ?? "";
const BPAY_PASSWORD = Deno.env.get("BPAY_PASSWORD") ?? "";
const BPAY_CLIENT_ID = Deno.env.get("BPAY_CLIENT_ID") ?? "ebankily";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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

async function getBpayToken(): Promise<string> {
  const res = await fetch(`${BPAY_BASE_URL}/authentification`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "password",
      username: BPAY_USERNAME,
      password: BPAY_PASSWORD,
      client_id: BPAY_CLIENT_ID,
    }),
  });
  const data = await res.json();
  if (!data?.access_token) throw new Error("bpay_auth_failed");
  return data.access_token as string;
}

async function callPayment(
  token: string,
  params: { clientPhone: string; passcode: string; amount: string; operationId: string },
) {
  const res = await fetch(`${BPAY_BASE_URL}/payment`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({
      clientPhone: params.clientPhone,
      passcode: params.passcode,
      amount: params.amount,
      language: "FR",
      operationId: params.operationId,
    }),
  });
  return res.json();
}

async function checkTransaction(token: string, operationId: string) {
  const res = await fetch(`${BPAY_BASE_URL}/checkTransaction`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ operationId }),
  });
  return res.json();
}

// A handful of the bank's known French error messages translated for the
// customer-facing UI; anything else falls back to a generic Arabic message
// rather than showing raw French to the customer.
function translateBankError(message: string | null | undefined): string {
  if (!message) return "فشلت عملية الدفع، تحقق من البيانات وحاول مرة أخرى.";
  const known: Record<string, string> = {
    "Le numéro de mobile n'est pas enregistré": "رقم Bankily الذي أدخلته غير مسجل.",
    "Les détails du retrait spécifiés ne correspondent pas aux détails présents dans le système":
      "رمز التحقق الذي أدخلته غير صحيح.",
    "4 digits for passcode": "رمز التحقق يجب أن يكون 4 أرقام بالضبط.",
    "le MPIN n'a pas été changé après la souscription":
      "يجب تغيير رمز MPIN في تطبيق Bankily أولاً قبل استخدامه للدفع.",
    "Error occurred. Please try again later":
      "حدث خطأ لدى البنك، انتظر لحظة ثم أعد المحاولة.",
    "Solde insuffisant": "رصيد Bankily غير كافٍ لإتمام العملية.",
    "Insufficient balance": "رصيد Bankily غير كافٍ لإتمام العملية.",
  };
  return known[message] ?? `${message}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ status: "failed", message: "يجب تسجيل الدخول أولاً." }, 401);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const token = authHeader.replace(/^Bearer\s+/i, "");
    const { data: userData, error: userError } = await supabase.auth.getUser(token);
    if (userError || !userData?.user) {
      return json({ status: "failed", message: "يجب تسجيل الدخول أولاً." }, 401);
    }
    const userId = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const amount = Number(body?.amount);
    const payerPhone = String(body?.payerPhone ?? "").trim();
    const passcode = String(body?.passcode ?? "").trim();

    if (!amount || amount <= 0 || !payerPhone || !passcode) {
      return json({ status: "failed", message: "بيانات الدفع غير صحيحة." }, 400);
    }
    if (!BPAY_USERNAME || !BPAY_PASSWORD) {
      return json({ status: "failed", message: "خدمة الدفع غير مُهيأة بعد، حاول لاحقًا." }, 500);
    }

    const operationId = `AHDC${Date.now()}${Math.floor(100 + Math.random() * 900)}`;
    const bpayToken = await getBpayToken();

    const paymentResult = await callPayment(bpayToken, {
      clientPhone: payerPhone,
      passcode,
      amount: String(amount),
      operationId,
    });

    let finalStatus: "success" | "failed" | "pending" = "pending";
    let transactionId: string | null = paymentResult?.transactionId ?? null;
    let errorCode: number | null = paymentResult?.errorCode ?? null;
    let errorMessage: string | null = paymentResult?.errorMessage ?? null;

    if (paymentResult?.errorCode === 0 && paymentResult?.transactionId) {
      finalStatus = "success";
    } else if (paymentResult?.errorCode && paymentResult.errorCode !== 0 && paymentResult?.errorMessage) {
      // A concrete business rejection (wrong passcode, unregistered phone,
      // insufficient balance, ...) - no need to poll, it already failed.
      finalStatus = "failed";
    } else {
      // Ambiguous/timed-out first response - Bankily's own test environment
      // showed the payment can still be processed server-side even when the
      // initial call errors out, so poll checkTransaction before giving up.
      for (let attempt = 0; attempt < 3; attempt++) {
        await sleep(2000);
        const check = await checkTransaction(bpayToken, operationId);
        if (check?.status === "TS") {
          finalStatus = "success";
          transactionId = check.transactionId ?? transactionId;
          errorCode = check.errorCode ?? errorCode;
          break;
        }
        if (check?.status === "TF") {
          finalStatus = "failed";
          break;
        }
        // status "TA" (still ambiguous) -> keep polling until attempts run out.
      }
    }

    await supabase.from("customer_bpay_transactions").insert({
      user_id: userId,
      operation_id: operationId,
      amount,
      payer_phone: payerPhone,
      status: finalStatus,
      error_code: errorCode,
      error_message: errorMessage,
      transaction_id: transactionId,
    });

    // A credit failure downgrades the response instead of masking it (see
    // aihoudhoud's own bpay-payment - the same silent-failure bug there
    // once left a captain's bank payment taken with nothing ever credited
    // to their app wallet) - the customer_bpay_transactions row above is
    // already the durable record support can find by operationId to fix
    // the balance manually.
    let creditFailed = false;
    if (finalStatus === "success") {
      const { error: creditError } = await supabase.rpc(
        "credit_wallet_from_bpay",
        {
          p_user_id: userId,
          p_amount: amount,
          p_title: "شحن رصيد عبر Bpay",
        },
      );
      if (creditError) {
        console.error("credit_wallet_from_bpay failed", creditError);
        creditFailed = true;
      }
    }

    const message = creditFailed
      ? `تم خصم المبلغ من حسابك، لكن حدث خطأ أثناء إضافته لمحفظتك. تواصل مع الدعم فورًا مع رقم العملية: ${operationId}`
      : finalStatus === "success"
      ? "تم الدفع بنجاح، تم إضافة الرصيد فورًا."
      : finalStatus === "pending"
      ? "طلبك قيد التحقق من البنك، سيُضاف الرصيد تلقائيًا فور التأكيد."
      : translateBankError(errorMessage);

    // Reported as "pending" (not "success") when the credit failed, even
    // though the bank payment itself went through - the app's success
    // screen shouldn't tell the customer their balance was topped up when
    // it wasn't.
    return json({
      status: creditFailed ? "pending" : finalStatus,
      message,
      transactionId,
    });
  } catch (_e) {
    return json({ status: "failed", message: "تعذر الاتصال بخدمة الدفع، حاول مرة أخرى." }, 500);
  }
});
