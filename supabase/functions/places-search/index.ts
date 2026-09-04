// Proxies a Google Places Text Search call for the admin dashboard (web).
//
// google_places_search_service.dart's direct maps.googleapis.com call
// works fine on Android/iOS but is deliberately skipped on web: Google's
// Places REST API sends no CORS headers, so a browser fetch would just
// fail after a real network round trip. This function does the same
// search server-side (no CORS restriction between two servers) and
// returns plain JSON the browser's fetch can read normally, since this
// function's own CORS headers below are ours to set.
//
// Required secret:
//   GOOGLE_PLACES_SERVER_API_KEY  a Maps Platform key restricted (in
//     Google Cloud Console) to "Places API" only, with NO Android/iOS
//     application restriction - it's called from Supabase's servers, not
//     from a phone, so a package-name/bundle-ID restriction would reject
//     every call. Restrict by "API restrictions" only, not
//     "Application restrictions". Never reuse the Android-restricted key
//     the mobile apps carry - that one would fail here for the same
//     reason.
//
// Called by any signed-in admin (not gated further - Places search
// results aren't sensitive), same trust level as the destination search
// screens already open to any admin session.
//
// Google's formatted_address is often just a Plus Code or "Unnamed Road"
// in Nouakchott's less-mapped areas, so each result's coordinates are also
// matched against this app's own districts/neighborhoods registry via the
// nearest_place_area() function (20260831000086) and the match appended to
// the subtitle - this app's data knows the area's real name even when
// Google's doesn't.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GOOGLE_PLACES_SERVER_API_KEY =
  Deno.env.get("GOOGLE_PLACES_SERVER_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function nearestArea(
  lat: number,
  lng: number,
): Promise<{ district_name: string | null; neighborhood_name: string | null }> {
  const { data, error } = await supabase
    .rpc("nearest_place_area", { p_lat: lat, p_lng: lng })
    .maybeSingle();
  if (error || !data) return { district_name: null, neighborhood_name: null };
  return data;
}

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

// Nouakchott's rough center - same bias google_places_search_service.dart
// uses, and the same isWithinNouakchott-style bounding box to drop any
// stray result outside the city.
const NOUAKCHOTT_LAT = 18.0858;
const NOUAKCHOTT_LNG = -15.9785;
const MIN_LAT = 17.85;
const MAX_LAT = 18.35;
const MIN_LNG = -16.15;
const MAX_LNG = -15.75;

function isWithinNouakchott(lat: number, lng: number): boolean {
  return lat >= MIN_LAT && lat <= MAX_LAT && lng >= MIN_LNG && lng <= MAX_LNG;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!GOOGLE_PLACES_SERVER_API_KEY) {
    return json({ error: "GOOGLE_PLACES_SERVER_API_KEY not configured" }, 500);
  }

  let query = "";
  let limit = 8;
  try {
    const body = await req.json();
    query = typeof body.query === "string" ? body.query.trim() : "";
    if (typeof body.limit === "number" && body.limit > 0) {
      limit = Math.min(body.limit, 20);
    }
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  if (!query) return json({ results: [] });

  try {
    const url = new URL(
      "https://maps.googleapis.com/maps/api/place/textsearch/json",
    );
    url.searchParams.set("query", query);
    url.searchParams.set("location", `${NOUAKCHOTT_LAT},${NOUAKCHOTT_LNG}`);
    url.searchParams.set("radius", "20000");
    url.searchParams.set("language", "ar");
    url.searchParams.set("region", "mr");
    url.searchParams.set("key", GOOGLE_PLACES_SERVER_API_KEY);

    const response = await fetch(url.toString());
    if (!response.ok) {
      console.error(`places-search: HTTP ${response.status} from Google for query "${query}"`);
      return json({ results: [] });
    }

    const data = await response.json();
    if (data.status !== "OK") {
      console.error(
        `places-search: Google status "${data.status}" for query "${query}"` +
          (data.error_message ? ` - ${data.error_message}` : ""),
      );
      return json({ results: [] });
    }
    console.log(`places-search: query "${query}" -> ${data.results?.length ?? 0} raw results from Google`);

    const candidates = [];
    for (const row of data.results ?? []) {
      const lat = row.geometry?.location?.lat;
      const lng = row.geometry?.location?.lng;
      const placeId = row.place_id;
      const name = row.name;
      if (
        typeof lat !== "number" ||
        typeof lng !== "number" ||
        !placeId ||
        !name ||
        !isWithinNouakchott(lat, lng)
      ) {
        continue;
      }
      candidates.push({
        id: `google_${placeId}`,
        title: name,
        subtitle: row.formatted_address as string | null ?? null,
        latitude: lat,
        longitude: lng,
      });
      if (candidates.length >= limit) break;
    }

    const areas = await Promise.all(
      candidates.map((c) => nearestArea(c.latitude, c.longitude)),
    );
    const results = candidates.map((c, i) => {
      const area = areas[i];
      let subtitle = c.subtitle;
      if (area.neighborhood_name) {
        subtitle = subtitle
          ? `${subtitle} - حي ${area.neighborhood_name}`
          : `حي ${area.neighborhood_name}`;
      } else if (area.district_name) {
        subtitle = subtitle ? `${subtitle} - ${area.district_name}` : area.district_name;
      }
      return { ...c, subtitle };
    });

    return json({ results });
  } catch (_e) {
    return json({ results: [] });
  }
});
