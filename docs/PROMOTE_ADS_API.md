# Promote / Boost — Meta Ads backend (contract for the friend)

The Flutter **Boost** screen (`app/lib/features/promote/promote_screen.dart`) is
already built. It currently calls a stubbed `_boost()`; your job is to implement
the backend endpoint below and wire it to the **Meta Marketing API**, then flip
the Flutter call from the stub to the real API method.

The **AI Poster** path is fully done (rendered + shared on-device) — no backend
needed there.

---

## 1) Endpoint to implement

### `POST /promote/boost`  (artisan auth — Bearer access token)
Create a real ad campaign for one product.

**Request**
```json
{
  "product_id": "8c748ac5...",
  "budget_rupees": 200,
  "days": 5,
  "audience": "nearby",          // "nearby" | "india"
  "image_source": "studio"       // "poster" | "studio" | "gallery"
}
```

**Response (200)**
```json
{
  "status": "under_review",      // under_review | active | rejected | failed
  "ad_id": "1203...",
  "campaign_id": "video...",
  "estimated_reach": [2800, 6400],
  "permalink": "https://www.facebook.com/ads/..."   // optional
}
```

**Errors:** `402` (ad account not funded), `422` (bad budget/days), `502`
(Meta API error — return `{ "detail": "<meta error>" }`).

### `GET /promote/boosts`  (artisan auth) — optional, for a history screen
```json
[{ "product_id": "...", "ad_id": "...", "status": "active",
   "budget_rupees": 200, "days": 5, "reach": 4120, "spend_rupees": 140,
   "created_at": "2026-08-25T..." }]
```

---

## 2) Meta Marketing API mapping (what the endpoint does)

Base: `https://graph.facebook.com/v21.0/act_<AD_ACCOUNT_ID>/...`  (Bearer = access token)

1. **Campaign** — `POST /campaigns`
   `{ name, objective: "OUTCOME_TRAFFIC" (or OUTCOME_SALES/REACH), status: "PAUSED", special_ad_categories: [] }`
2. **Ad Set** — `POST /adsets`
   `{ name, campaign_id, daily_budget: <paise = budget_rupees*100/days>, billing_event: "IMPRESSIONS",
      optimization_goal: "REACH" (or LINK_CLICKS), bid_strategy: "LOWEST_COST_WITHOUT_CAP",
      start_time, end_time (start + days),
      targeting: { geo_locations: {...}, age_min: 18, age_max: 65 }, status: "PAUSED" }`
   - `audience == "nearby"` → `geo_locations` = the artisan's city / lat-lng + radius
   - `audience == "india"`  → `geo_locations: { countries: ["IN"] }`
3. **Ad Creative** — `POST /adcreatives`
   `{ name, object_story_spec: { page_id: <PAGE_ID>, link_data: { image_hash, message: <AI caption>, link: <product/shop url>, call_to_action: {type:"ORDER_NOW"} } } }`
   - The image: upload first → `POST /act_<id>/adimages` (multipart) → get `image_hash`
   - **image_source** decides which image bytes to upload:
     - `studio` → the product's `enhanced_image_url` (fetch from GCS via our `/uploads/..`)
     - `poster` → generate the poster server-side (see note) or accept an uploaded PNG
     - `gallery` → the app should upload the chosen file (add a `file` multipart or a pre-upload step)
4. **Ad** — `POST /ads`  `{ name, adset_id, creative: { creative_id }, status: "PAUSED" }`
5. To go live: set the campaign/adset/ad `status: "ACTIVE"` (or create them ACTIVE). Keep **PAUSED** during dev to avoid spend.

Reuse the existing caption logic (Gemini) for `message`; the app already writes a
good bilingual caption in `_caption()` — you can pass it up in the request or
regenerate server-side.

---

## 3) Config (set on Cloud Run — do NOT commit)
Add to `backend/app/core/config.py` and set via `gcloud run deploy --update-env-vars`:
```
META_ACCESS_TOKEN     # system-user token, ads_management + ads_read
META_AD_ACCOUNT_ID    # digits only (act_ is added in code)
META_PAGE_ID
META_APP_ID
META_APP_SECRET       # for appsecret_proof (recommended)
META_API_VERSION=v21.0
```
Own ad account in **development mode** works WITHOUT App Review. Others' accounts
need App Review (`ads_management`) + business verification — that's the scale path.

Security note: send `appsecret_proof = HMAC-SHA256(access_token, app_secret)` with
each call for hardened auth.

---

## 4) Flutter side — flip the stub to real (1 place)
In `app/lib/features/promote/promote_screen.dart`, `_BoostScreenState._boost()`:
- replace the `Future.delayed(...)` mock with a call to a new `Api.boostProduct(...)`
  method (add it in `app/lib/data/api.dart`) that POSTs `/promote/boost` and returns
  the JSON above.
- On success show the same dialog with the real `estimated_reach`.
- For `image_source == "gallery"`, upload the picked file first (add a small
  `/promote/ad-image` upload endpoint, or include it in the boost multipart).

That's it — the whole UI/flow is already there; you're filling the backend.
