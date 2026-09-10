# AL HODHOD Admin Dashboard — Web Deployment Guide

Reference only — nothing here has been deployed. Follow this when you're
ready to put the dashboard on a real domain.

## 1. Local verification (do this first, every time)

```bash
flutter pub get
flutter analyze
flutter run -d chrome          # live local check in a real browser
flutter build web --release    # production build -> build/web/
```

`build/web/` is a static site. Every file needed to host it is inside that
folder after `flutter build web --release`.

## 2. Supabase configuration for web

In your Supabase project dashboard → **Authentication → URL Configuration**:

- **Site URL**: your production admin domain (e.g. `https://admin.alhodhod.example`)
- **Redirect URLs**, add both:
  - `http://localhost:PORT/*` (whatever port `flutter run -d chrome` uses — check the terminal output; `*` wildcard covers Flutter's dev-server hot-reload path changes)
  - `https://admin.alhodhod.example/*` (your real domain, once you have one)

No other Supabase configuration changes are needed — the admin dashboard
reuses the exact same Supabase project, URL, and anon key as the mobile
apps (`.env`, loaded by `SupabaseConfig.initialize()`), and the anon key is
safe to ship in a web build (it's designed for client-side use; RLS is
what actually protects the data — see the migrations under
`supabase/migrations/`).

## 3. Never expose the service-role key

The admin dashboard never uses the Supabase **service-role** key — every
sensitive action (approvals, wallet adjustments, admin promotion, ...)
goes through a `SECURITY DEFINER` Postgres function that re-checks the
caller's role server-side (see `20260712000028_admin_functions.sql`).
Do not add the service-role key to `.env`, to any Flutter file, or to any
hosting provider's environment variables for this app. If you ever need
service-role-only operations (e.g. creating a brand new admin login from
scratch instead of promoting an existing account), do that from a secure
server context (a Supabase Edge Function, or the Supabase dashboard
directly) — never from this Flutter Web app.

## 4. Routing (path URLs, not hash)

`main.dart` calls `usePathUrlStrategy()`, so routes look like
`/admin/dashboard` instead of `/admin/#/dashboard`. This requires the
hosting provider to serve `index.html` for **any** path under `/admin/*`
(a "SPA fallback" / "rewrite all routes to index.html" rule) — otherwise
refreshing the browser on a deep link like `/admin/customers` 404s.

## 5. Provider-specific steps

Deploy the contents of `build/web/` after running
`flutter build web --release`.

### Vercel

1. `vercel.json` in the project root (or `build/web/` if deploying that
   folder standalone):
   ```json
   {
     "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
   }
   ```
2. Build command: `flutter build web --release`
3. Output directory: `build/web`

### Netlify

1. `build/web/_redirects` file:
   ```
   /*    /index.html   200
   ```
2. Build command: `flutter build web --release`
3. Publish directory: `build/web`

### Firebase Hosting

1. `firebase init hosting`, set public directory to `build/web`.
2. In `firebase.json`, add a rewrite:
   ```json
   {
     "hosting": {
       "public": "build/web",
       "rewrites": [{ "source": "**", "destination": "/index.html" }]
     }
   }
   ```
3. `firebase deploy --only hosting`

### Cloudflare Pages

1. Build command: `flutter build web --release`
2. Build output directory: `build/web`
3. Add a `build/web/_redirects` file (same syntax as Netlify):
   ```
   /*    /index.html   200
   ```

## 5b. MapTiler API key (optional)

The admin dashboard renders live maps (operator dispatch, live operations,
trip route editing) via `RealMapWidget`, same as the mobile apps. Without a
`MAPTILER_API_KEY` env var set on the hosting provider (e.g. Vercel project
settings → Environment Variables), it falls back to free OpenStreetMap
tiles automatically - see `lib/core/services/map_tile_provider.dart`. Add
the key there (no code change needed) to switch this deployment to
MapTiler tiles.

## 6. Google Maps API key (only needed for the destination map picker, Phase 2)

The admin dashboard itself doesn't use Google Maps. If you later add the
customer-facing mobile app's map picker to a web build too, configure the
key via `android/local.properties` → `MAPS_API_KEY` (Android) as already
documented in the Phase 2 report; that key is unrelated to this admin
dashboard's deployment.

## 7. Post-deploy checklist

- [ ] Visit `/admin/login` on the real domain, confirm it loads (not a 404).
- [ ] Sign in with a real admin account, confirm redirect to `/admin/dashboard`.
- [ ] Refresh the browser on a deep route (e.g. `/admin/customers`) — must
      NOT 404 (confirms the SPA rewrite rule above is active).
- [ ] Sign out, then try navigating directly to `/admin/dashboard` — must
      redirect to `/admin/login`.
- [ ] Confirm the Supabase **Redirect URLs** allow-list includes the real
      domain (step 2).
