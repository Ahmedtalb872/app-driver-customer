/// Nouakchott's approximate bounding box and center - shared by every place
/// client code touches by lat/lng, so the number only needs to change in one
/// spot. Must stay in sync with the box `search_destinations` and the
/// `*_within_nouakchott` check constraints enforce server-side (see
/// supabase/migrations/20260809000052_nouakchott_bounds_search.sql) - SQL
/// and Dart can't literally share a constant, so this comment is the only
/// thing keeping the two in sync.
const nouakchottMinLat = 17.90;
const nouakchottMaxLat = 18.30;
const nouakchottMinLng = -16.20;
const nouakchottMaxLng = -15.75;

/// Nouakchott's rough geographic center, used to bias/center location-aware
/// API calls (e.g. Google Places Text Search) and the admin place-picker map.
const nouakchottCenterLat = 18.0858;
const nouakchottCenterLng = -15.9785;

bool isWithinNouakchott(double lat, double lng) =>
    lat >= nouakchottMinLat &&
    lat <= nouakchottMaxLat &&
    lng >= nouakchottMinLng &&
    lng <= nouakchottMaxLng;
