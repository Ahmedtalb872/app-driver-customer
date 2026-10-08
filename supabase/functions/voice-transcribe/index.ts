// Transcribes a short voice-search recording via Google Cloud
// Speech-to-Text, server-side - see VoiceTranscriptionService
// (lib/core/services/voice_search/voice_transcription_service.dart), which
// records audio on-device (lib/features/trips/voice_ride_request_sheet.dart)
// and sends it here as base64 instead of using the phone's own built-in
// recognizer (the free `speech_to_text` package). That on-device recognizer
// is what VoiceRoutePipeline's Stage 2/3 corrections were built to work
// around - it mishears local/Hassaniya place names often enough that
// customers kept hitting "لم أجد مكان" even after those corrections. Google's
// model, fed this app's own place names as recognition hints below, is
// meant to fix the mishearing at its source instead of only compensating
// for it after the fact.
//
// Required secret:
//   GOOGLE_SPEECH_API_KEY  a Google Cloud API key restricted (in Google
//     Cloud Console) to "Cloud Speech-to-Text API" only, with NO
//     Android/iOS application restriction - it's called from Supabase's
//     servers, not from a phone, so an app-restricted key would reject
//     every call here (same reasoning as places-search's
//     GOOGLE_PLACES_SERVER_API_KEY).
//
// Called by any signed-in user (not admin-only) - gated to a valid session
// so the project's Speech-to-Text quota/billing can't be spent with no
// credentials at all, same posture as places-search.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GOOGLE_SPEECH_API_KEY = Deno.env.get("GOOGLE_SPEECH_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

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

// Every active place's name plus its admin-entered alt_names
// (20261007000111_place_alt_names_search.sql) - fed to Google as
// "speech context" phrases so local names it would otherwise mishear get a
// recognition boost. Capped well under Google's per-request phrase/char
// limits; this project's place count is in the hundreds, not thousands.
async function fetchPlaceHints(limit = 500): Promise<string[]> {
  const { data, error } = await supabase
    .from("places")
    .select("name_ar, alt_names")
    .eq("is_active", true)
    .limit(limit);
  if (error || !data) return [];

  const phrases = new Set<string>();
  for (const row of data as { name_ar: string | null; alt_names: string[] | null }[]) {
    if (row.name_ar) phrases.add(row.name_ar);
    for (const alt of row.alt_names ?? []) {
      if (alt) phrases.add(alt);
    }
  }
  return Array.from(phrases).slice(0, 500);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!GOOGLE_SPEECH_API_KEY) {
    return json({ error: "GOOGLE_SPEECH_API_KEY not configured" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData?.user) return json({ error: "unauthorized" }, 401);

  let audioBase64 = "";
  try {
    const body = await req.json();
    audioBase64 = typeof body.audio === "string" ? body.audio : "";
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  if (!audioBase64) return json({ transcript: "" });

  const hints = await fetchPlaceHints();

  try {
    const url =
      `https://speech.googleapis.com/v1/speech:recognize?key=${GOOGLE_SPEECH_API_KEY}`;
    const payload = {
      config: {
        // Deliberately omitted: encoding/sampleRateHertz. The client
        // records a WAV file (see VoiceTranscriptionService) and sends its
        // bytes - including the header - as-is; Google reads the format
        // and sample rate straight from that header for WAV/FLAC input,
        // which avoids this function having to know or trust whatever
        // sample rate the recording plugin actually used on a given
        // device.
        languageCode: "ar-SA",
        alternativeLanguageCodes: ["ar-EG", "ar-MA"],
        speechContexts: hints.length > 0 ? [{ phrases: hints }] : undefined,
        enableAutomaticPunctuation: false,
      },
      audio: { content: audioBase64 },
    };

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const data = await response.json();

    if (!response.ok) {
      console.error(
        `voice-transcribe: HTTP ${response.status} from Google - ${JSON.stringify(data)}`,
      );
      return json({ transcript: "" });
    }

    const transcript = data.results?.[0]?.alternatives?.[0]?.transcript ?? "";
    return json({ transcript });
  } catch (e) {
    console.error("voice-transcribe: exception", e);
    return json({ transcript: "" });
  }
});
