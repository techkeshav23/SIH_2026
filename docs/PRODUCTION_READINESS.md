# KalaSetu — Production-Readiness Verification
### Multi-agent audit (4 agents: backend/deploy · app · AI/govt · feature-gap). Honest scorecard.

---

## ✅ v2 — Hardening progress (Aug 2026)
Most P0s from the audit below are now fixed. Status of each:

| # | P0 item | Status |
|---|---|---|
| 1 | SQLite → data loss on Cloud Run | **FIXED & VERIFIED** — Cloud SQL Postgres (`kalasetu-db`, Mumbai) wired via socket connector; OTP login persists a user row across restarts |
| 2 | `APP_ENV=dev` leaks OTP | **FIXED** — prod runs `APP_ENV=prod`; OTP return now gated behind an explicit `ALLOW_DEV_OTP` flag |
| 3 | Default `SECRET_KEY` | **FIXED** — strong random secret set in prod env |
| 5 | Voice cataloging simulated | **FIXED** — real mic recording (`record` 6.2.1) → WAV → Vertex multimodal `/ai/catalog-from-voice`; APK compiles |
| 6 | Pricing ML model not in prod | **FIXED & VERIFIED** — `.pkl` baked into image; prod predicted base ≈₹778 (heuristic would give ₹2400) |
| 7 | Image bg-removal is Pillow-only | **FIXED & VERIFIED** — `rembg` (u2netp, baked model) in prod; real cutout in **~2s warm** (Pillow fallback on error). First call after a cold start takes longer (ONNX init) — warm the service before a live demo |
| 8 | Reviews/notifications dead in real mode | **FIXED & VERIFIED** — persisted DB-backed endpoints (`/products/{id}/reviews`, `/notifications`); notifications written on every order/review event |
| 9 | No route guards / 401 handling | **FIXED** — GoRouter redirect (login + buyer/artisan separation) + auto-logout→login on unrecoverable 401 |
| — | Order fulfilment dead-ends at `paid` | **ADDED** — ship → confirm-delivery → completed, + buyer cancel; role-aware app UI + notifications |
| 4 | Real SMS (MSG91/Twilio) | Still console OTP (demo). Provider-abstracted; add keys for real SMS |

Backend: **54/54 tests pass.** Payments intentionally remain **mock** (per team decision) — the flow works end-to-end; wire Razorpay keys when a merchant account is ready.

### Phase 5 — commerce & compliance (all verified on prod)
| Item | Status |
|---|---|
| Order fulfilment | **VERIFIED** — ship → confirm-delivery → completed, + buyer cancel; role-aware app UI + notifications |
| DPDP Act 2023 consent | **VERIFIED** — first-run consent gate (versioned + timestamped, stored per user/buyer), privacy policy + Grievance Officer screen |
| Buyer delivery addresses | **VERIFIED** — address book (default handling), picked at checkout, denormalized ship-to snapshot shown to the artisan for dispatch |
| Artisan storefront | **VERIFIED** — public shop page (bio + listed products), reachable via "View shop" on any product |

Compliance moved from **5/100** (no consent/policy) to a working DPDP consent trail + privacy policy + grievance officer — the main govt legal blocker is addressed (formal VAPT/DPO registration still pending for a real launch).

*The original audit (unchanged) follows for reference.*

---

## TL;DR
**Excellent demo/MVP, NOT production-ready.** The app looks and demos great, real Vertex AI text→listing + pricing work, and it's deployed on Cloud Run. But there are **critical security/persistence bugs in the deploy**, the **flagship voice feature is simulated (not real)**, **image bg-removal isn't actually running**, and **payments/KYC/delivery/compliance are missing or stubbed**.

## Scorecard
| Dimension | Score | Verdict |
|---|---|---|
| Backend + Deployment | **32/100** | Good code, unsafe deploy (data loss + auth bypass) |
| Flutter App | **58/100** | Polished demo; several features dead/fake in *real* mode |
| AI features (vs PS) | **42/100** | Backend AI real; voice simulated, image Pillow-only, pricing model not in prod |
| Commerce | 20/100 | Mock pay only; no real payments/payout/KYC/address/logistics |
| Marketplace/trust | 15/100 | No storefront, reviews 404 in real mode, no verified-seller |
| Govt (ONDC/GeM/Bhashini) | 10/100 | Off-by-default scaffolds (NotImplementedError) |
| Compliance/legal | 5/100 | No DPDP consent, privacy policy, T&C, VAPT |
| Ops | 45/100 | CI + Alembic + Sentry-ready; no staging/backups/alerts |

**Overall ≈ 40/100 — a strong hackathon demo, an early prototype for production.**

---

## ⚠️ HONESTY FLAGS (do NOT overclaim to judges)
- ✅ **Can claim:** real Vertex AI (Gemini 2.5 Flash, Mumbai), working text→bilingual listing + pricing rationale, deployed backend, full app + offline demo.
- ❌ **Do NOT claim as live:** in-app **voice cataloging** (it's simulated), **AI background removal** (Pillow only; demo shows a *canned* before/after, not your photo), a **deployed pricing ML model** (falls back to heuristic in prod), and **ONDC/GeM/Bhashini/DigiLocker** integrations (all stubs).

---

## 🔴 P0 — Critical (fix these first)

### Security & deploy (mostly 1-line env/config — huge ROI)
1. **SQLite on Cloud Run = data loss on every restart/idle.** Move to **Cloud SQL (Postgres)** — code already supports it; only the deployed `DATABASE_URL` is wrong.
2. **`APP_ENV=dev` in prod leaks the OTP** → anyone logs in as anyone. Set **`APP_ENV=prod`**.
3. **Default `SECRET_KEY=dev-secret-change-me`** signs JWTs → tokens forgeable. Set a **random secret** (Secret Manager).
4. **No real SMS** (console OTP) → set up **MSG91/Twilio** for real login.

### Make the demo match the pitch (highest judge impact)
5. **Real in-app voice recording** — flagship feature is 100% simulated. Add a build-compatible recorder (`flutter_sound`) → wire the *already-working* `/ai/catalog-from-voice` (Vertex multimodal). **Biggest gap vs PS 26090.**
6. **Ship the pricing ML model to prod** — `ml/pricing_model.pkl` isn't in the container (path resolves outside `backend/`), so prod silently uses an 8-row heuristic. Bake it in + log which path is used.
7. **Real image background removal** — enable `rembg` (or Cloudinary), and stop the demo from swapping in a canned before/after; process the user's actual photo.

### App broken-in-real-mode
8. **Reviews & Notifications have no backend** → in real (logged-in) mode they're dead/misleading ("review submitted" but nothing saved; bell always empty). Add backend endpoints or hide these in real mode.
9. **No route guards / 401 handling** — logged-out deep links show broken authed screens; buyer can reach artisan screens. Add GoRouter `redirect` by login+role.

---

## 🟡 P1 — Real product needs
- Real **payments (UPI/Razorpay)** + **payout/settlement** to artisan
- **Bank + Aadhaar KYC** (beneficiary eligibility) · **DigiLocker** verification
- **Buyer delivery addresses** + attach to order · **logistics/tracking**
- **Order fulfilment** endpoints (ship/deliver/cancel/return — currently dead-ends at `paid`)
- **ONDC seller onboarding** (start paperwork now) · **Bhashini** Indic STT/MT · **GeM** listing
- **Server-side cart + wishlist** (cart is client-only, lost on restart) · **artisan storefront** page
- **DPDP consent + Privacy Policy + T&C + grievance officer** (legal blocker for govt)
- **First-run onboarding** (voice + language picker) · **IVR/help**
- **Redis-backed** OTP/rate-limit/quota (in-memory now → breaks on scale/restart)
- **Full localization** (a few hardcoded English strings remain: Cancel button, home banner)

## 🟢 P2 — Hardening
- Sentry DSN on, monitoring/alerts, cost budget alert (Vertex)
- Staging env, DB backups + tested restore, incident runbook
- Migrations as a release step (not container boot), CI coverage gate + deploy job
- WCAG accessibility formal audit + prompt-injection guardrails on AI
- Product delete/stock, multiple images, before/after slider, B2B RFQ/MOQ, invoices/GST

---

## Fastest path to a *credible* product
1. **1-hour config fixes:** APP_ENV=prod + real SECRET_KEY + Cloud SQL Postgres + ship pricing model → deploy is safe & durable, prod AI real.
2. **Voice recorder** (P0-5) → the flagship feature becomes real; demo matches pitch.
3. **Enable rembg** (P0-7) → real "AI photo enhancement".
4. Then the P1 commerce/govt/compliance long tail for an actual launch.

*Audit v1 · read-only. See NEXT_STEPS.md and PRODUCTION_ROADMAP.md for the deeper roadmap.*
