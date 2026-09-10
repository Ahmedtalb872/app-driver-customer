// Reads the printed text off a captain's uploaded document (national ID,
// driving license, vehicle registration, insurance...) via Google Cloud
// Vision's DOCUMENT_TEXT_DETECTION, and stores it on the row so the admin
// dashboard can show it next to the document's thumbnail - the reviewer
// gets the printed numbers/dates/names as selectable text instead of
// having to zoom into a photographed ID card to read it. This is read-only
// assistance for the human reviewer, not an auto-approval mechanism -
// nothing here ever changes a document's approved/rejected status.
//
// Reuses the same GOOGLE_PLACES_SERVER_API_KEY secret places-search
// already uses (same Google Cloud project/key) - just add "Cloud Vision
// API" to that key's API restrictions alongside "Places API" in Google
// Cloud Console. No separate key/secret needed.
//
// Called two ways, both best-effort (a failure here never blocks anything
// else - the document is already uploaded and reviewable regardless):
//   1. Right after a captain uploads a document
//      (CaptainDocumentsRepository.uploadDocument/triggerExtraction),
//      fire-and-forget.
//   2. Lazily by the admin dashboard for any older row still
//      'not_attempted', or manually re-triggered on a 'failed' one
//      (captain_detail_panel.dart's "إعادة الفحص" action).
//
// Caller must be the document's own captain or an admin - same trust model
// as the captain_documents RLS policy itself
// (20260717000034_captain_documents.sql), re-checked here since this
// function uses the service_role key (bypasses RLS) to read/update the row
// and to read the file bytes from Storage.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GOOGLE_PLACES_SERVER_API_KEY =
  Deno.env.get("GOOGLE_PLACES_SERVER_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

// Vision's REST API wants the image inline as base64. btoa() can't take a
// raw byte array directly and String.fromCharCode(...bytes) blows the
// call-stack on a multi-MB image, so this builds the binary string in
// fixed-size chunks first.
function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

// Document types with nothing printed worth reading (a face/car photo) -
// skipped without spending a Vision call. PDFs are also skipped: Vision's
// image-annotation endpoint reads raster images, not PDFs directly.
const NO_TEXT_DOCUMENT_TYPES = new Set(["profile_photo", "vehicle_photo"]);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!GOOGLE_PLACES_SERVER_API_KEY) {
    return json({ error: "GOOGLE_PLACES_SERVER_API_KEY not configured" }, 500);
  }

  let documentId = "";
  try {
    const body = await req.json();
    documentId = typeof body.document_id === "string" ? body.document_id : "";
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  if (!documentId) return json({ error: "document_id is required" }, 400);

  const authHeader = req.headers.get("Authorization") ?? "";
  const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData?.user) return json({ error: "unauthorized" }, 401);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: doc, error: docError } = await supabase
    .from("captain_documents")
    .select("id, captain_id, document_type, file_path, mime_type")
    .eq("id", documentId)
    .maybeSingle();
  if (docError || !doc) return json({ error: "document_not_found" }, 404);

  if (doc.captain_id !== userData.user.id) {
    const { data: isAdmin } = await supabase.rpc("is_admin_uid", {
      p_uid: userData.user.id,
    });
    if (!isAdmin) return json({ error: "forbidden" }, 403);
  }

  if (
    NO_TEXT_DOCUMENT_TYPES.has(doc.document_type) ||
    doc.mime_type === "application/pdf"
  ) {
    await supabase
      .from("captain_documents")
      .update({ extraction_status: "skipped", extracted_at: new Date().toISOString() })
      .eq("id", documentId);
    return json({ status: "skipped" });
  }

  await supabase
    .from("captain_documents")
    .update({ extraction_status: "pending" })
    .eq("id", documentId);

  try {
    const { data: fileBlob, error: downloadError } = await supabase.storage
      .from("captain-documents")
      .download(doc.file_path);
    if (downloadError || !fileBlob) throw new Error("download_failed");

    const bytes = new Uint8Array(await fileBlob.arrayBuffer());
    const base64 = bytesToBase64(bytes);

    const visionResponse = await fetch(
      `https://vision.googleapis.com/v1/images:annotate?key=${GOOGLE_PLACES_SERVER_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          requests: [
            {
              image: { content: base64 },
              features: [{ type: "DOCUMENT_TEXT_DETECTION" }],
              // Mauritanian ID/vehicle documents mix Arabic and French.
              imageContext: { languageHints: ["ar", "fr"] },
            },
          ],
        }),
      },
    );
    const visionData = await visionResponse.json();
    const annotation = visionData?.responses?.[0];

    if (annotation?.error) {
      console.error(
        `extract-document-text: Vision error for document ${documentId} - ${annotation.error.message}`,
      );
      await supabase
        .from("captain_documents")
        .update({ extraction_status: "failed", extracted_at: new Date().toISOString() })
        .eq("id", documentId);
      return json({ status: "failed" });
    }

    const text = (annotation?.fullTextAnnotation?.text as string | undefined)
      ?.trim() ?? "";
    await supabase
      .from("captain_documents")
      .update({
        extracted_text: text || null,
        extraction_status: "done",
        extracted_at: new Date().toISOString(),
      })
      .eq("id", documentId);

    console.log(
      `extract-document-text: document ${documentId} (${doc.document_type}) -> ${text.length} chars`,
    );
    return json({ status: "done", extracted_text: text });
  } catch (e) {
    console.error(`extract-document-text: failed for document ${documentId} - ${e}`);
    await supabase
      .from("captain_documents")
      .update({ extraction_status: "failed", extracted_at: new Date().toISOString() })
      .eq("id", documentId);
    return json({ status: "failed" });
  }
});
