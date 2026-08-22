# KalaSetu — What's Left to Make It a Proper App
### Grounded in the current state (Aug 2026). Checklist, prioritized.

## Where we are now ✅
A genuinely strong **demo/MVP**: full Flutter app (2 roles, ~14 screens, sidebar + bottom
nav), bilingual (hi/en) + read-aloud TTS + large-text, offline demo mode with real craft
photos, buyer search/PDP/order/pay, artisan create→AI→price→publish, order timeline,
profile/settings. Backend: FastAPI (OTP+JWT auth, products, AI orchestration, order
lifecycle, mock payments, dashboard, 43 tests, Alembic, Celery, Docker). Vertex AI wired
(stubs without keys). Web landing page. Release APK ~20 MB.

**The core gap:** most of what shines runs in **demo mode**. The real backend + real AI +
real payments + real infra are not yet connected end-to-end on a device. That's step 1.

---

## 🔴 PHASE 1 — Make it REAL (connect demo → live). ~2–3 weeks
The single most important phase: turn simulations into working integrations.
- [ ] **Deploy the backend** (Render/Railway/Cloud Run) → app works without a local server
- [ ] **Real AI wiring + testing:**
  - [ ] Vertex AI creds (GCP project, service account) → test voice→listing + pricing (`check_ai.py`)
  - [ ] Image enhance: wire **rembg** (or Cloudinary AI) for real background removal
  - [ ] Pricing: build a real comparables dataset (scrape Meesho/Amazon Karigar/GeM), retrain
- [ ] **Real OTP/SMS** (MSG91/Gupshup/Twilio) — replace console OTP
- [ ] **Object storage** for images (Cloudinary/S3) — replace local disk
- [ ] **Point the app at the deployed API** (`--dart-define=BASE_URL=...`), test full real flow on a device

## 🔴 PHASE 2 — In-app voice + media (the hero feature). ~1–2 weeks
- [ ] **Real in-app voice recording** — add a build-compatible recorder (the old `record` pkg conflicts; use `flutter_sound`/`mic_stream`), wire to the working `/ai/catalog-from-voice`
- [ ] **Bhashini** integration for Indic STT/translation (govt-aligned, big pitch point)
- [ ] **Multiple product images + gallery** (not camera-only, not single image)
- [ ] Product **edit / delete / mark out-of-stock**

## 🟡 PHASE 3 — Commerce completeness. ~3–4 weeks
- [ ] **Real payments** (Razorpay/UPI) — replace the mock gateway; settlement/payout to artisan
- [ ] **Payout details**: bank/UPI + basic Aadhaar KYC (needed for govt beneficiary payouts)
- [ ] **Buyer addresses + delivery** (orders currently have no shipping destination)
- [ ] **Cart & multi-item checkout** (buyer)
- [ ] **Order fulfilment**: mark-shipped, tracking, delivered (lifecycle currently ends at `paid`)
- [ ] **Ratings & reviews** (trust signals) + **artisan storefront** page
- [ ] **Notifications**: FCM push + in-app centre (order/inquiry/payment events)

## 🟡 PHASE 4 — Govt integrations (the differentiators). ~3–4 weeks (start paperwork NOW)
- [ ] **ONDC** seller-app onboarding (catalog publish, search protocol) — long lead time
- [ ] **GeM** seller listing / assisted flow
- [ ] **DigiLocker / Aadhaar** artisan verification
- [ ] Map to MoSJE beneficiary schemes if a data MoU exists

## 🟡 PHASE 5 — Production hardening. ~2–3 weeks (runs alongside)
- [ ] **Postgres (managed) in prod** + backups tested; Redis + Celery worker live (durable AI jobs)
- [ ] **Observability**: turn on Sentry (DSN), metrics/alerts, cost dashboard
- [ ] **CI/CD**: auto-deploy pipeline; the GitHub Actions we have runs analyze+tests already
- [ ] **More tests**: integration + a load test; raise coverage on critical paths
- [ ] **Security**: rotate secrets → secrets manager, 3rd-party **VAPT** (often required for govt), fix findings
- [ ] **Offline robustness**: cache orders/stats, queue edits/actions (currently only new drafts)

## 🟢 PHASE 6 — Compliance & accessibility (govt-grade). ~2–3 weeks
- [ ] **DPDP Act 2023**: explicit consent screen, data-use notice, access/erasure, retention
- [ ] **Privacy Policy + T&C** (legal review) + grievance officer contact
- [ ] **Accessibility audit** (WCAG-aligned): TalkBack labels, contrast, tap targets, usability test with *real* artisans
- [ ] Data residency (already Vertex asia-south1/Mumbai ✓)

## 🟢 PHASE 7 — Onboarding, launch & pilot. ~2–3 weeks + ongoing
- [ ] **First-run onboarding** (icon + voice, language picker) — key for low-literacy users
- [ ] **Help & support**: IVR/toll-free + short how-to videos
- [ ] **Play Store**: app signing, store listing, data-safety form, screenshots
- [ ] **Closed pilot** with 20–50 artisans in 1–2 clusters; fix top issues; measure first-sale rate
- [ ] Staged public rollout

---

## ⏳ Accounts/keys to procure NOW (critical path — long lead times)
1. **GCP + Vertex AI** (enable API, service account) — for real AI
2. **Bhashini (ULCA)** account — govt language stack
3. **ONDC / GeM** seller onboarding — slowest, start first
4. **SMS provider** (MSG91/Gupshup) — real OTP
5. **Razorpay** (or UPI PSP) — payments
6. **Play Store** developer account — publishing
7. **Cloudinary/S3**, **Sentry**, **Render/Cloud** — infra

## Rough total
~**3–4 months** with a focused 4–6 person team to a real pilot launch. **Phase 1 (~2–3 weeks)
is the highest leverage** — it converts the impressive demo into a genuinely working product.

---
*See also: PRODUCTION_ROADMAP.md (deeper phase plan) and UI_AUDIT.md (feature gaps).*
