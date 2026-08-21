# KalaSetu — Production Roadmap
### From hackathon MVP → production-grade, govt-deployable platform

> Companion to [PLAN.md](PLAN.md) (the hackathon build plan). This document is the
> **post-MVP** plan to take KalaSetu to real users at MoSJE scale.
> Read `Definition of Done` first, then the phases.

---

## 0. Where we are today (baseline)

**Working prototype (~70% demo-ready, ~30% production-ready).**

| Layer | Have | Reality |
|---|---|---|
| Mobile | Flutter app, full flow, offline drafts, i18n | Not yet run on a real device; camera/mic untested |
| Backend | FastAPI, auth/products/AI/pricing/buyers | SQLite, in-process background tasks, dev-grade auth |
| AI | Gemini wired (voice→listing, pricing); stubs | Real Gemini path not yet validated with a key |
| Infra | Local only | No deploy, no CI, no monitoring, no tests |
| Security | JWT + OTP scaffold | OTP hardcoded, CORS `*`, no rate limits, no upload validation |

**Guiding principle:** ship in **thin vertical slices**, each phase independently
deployable and demonstrable. Never a 3-month big-bang. Every phase ends with
something running in a real environment behind a feature flag.

---

## 1. Definition of Done — "Production Ready" exit checklist

The platform is production-ready when ALL of these are true:

- [ ] **Security:** real OTP/SMS, rate limiting, upload validation, secrets in a manager, pen-test passed, HTTPS everywhere
- [ ] **Reliability:** 99.5% uptime target, durable async jobs (survive restart), graceful AI degradation, health/readiness probes
- [ ] **Data:** Postgres with migrations, backups + restore tested, object storage for media, PII encrypted at rest
- [ ] **Quality:** >70% critical-path test coverage, CI green gate on every PR, staged rollout, rollback runbook
- [ ] **Observability:** centralized logs, error tracking (Sentry), metrics dashboards, alerting on SLOs
- [ ] **Commerce:** buyer auth, orders, payments/settlement (or verified external), inquiry→order lifecycle
- [ ] **Compliance:** DPDP Act (consent, data rights), accessibility (WCAG-aligned), security audit, T&C + privacy policy
- [ ] **Scale:** load-tested to target concurrent users, autoscaling, CDN for media
- [ ] **Ops:** on-call runbooks, incident process, cost monitoring, documented deployment

---

## 2. Target architecture (production)

```
                        ┌────────────── CDN (Cloudflare) ──────────────┐
 Flutter app  ─────────►│  media (images)          static assets       │
 (Play Store) │         └───────────────────────────────────────────────┘
              │  HTTPS
              ▼
        ┌───────────────┐     ┌──────────────────────────────────────┐
        │  API Gateway  │────►│  FastAPI (stateless, autoscaled x N)  │
        │  + WAF + rate │     │  auth · catalog · pricing · orders    │
        └───────────────┘     └───┬───────────────┬──────────────┬────┘
                                   │               │              │
                        ┌──────────▼───┐   ┌───────▼──────┐  ┌────▼───────────┐
                        │  Postgres    │   │  Redis       │  │ Object storage │
                        │ (managed,HA) │   │ cache+broker │  │ (S3/Cloudinary)│
                        └──────────────┘   └───────┬──────┘  └────────────────┘
                                                   │
                                     ┌─────────────▼──────────────┐
                                     │  Celery workers (AI jobs)  │
                                     │  image · voice · pricing   │
                                     └──────┬───────────┬─────────┘
                                    ┌───────▼───┐  ┌────▼─────────┐
                                    │  Gemini   │  │ Bhashini/ONDC│
                                    │  rembg    │  │ GeM / SMS    │
                                    └───────────┘  └──────────────┘
      Observability: Sentry (errors) · Prometheus/Grafana (metrics) · Loki (logs)
      CI/CD: GitHub Actions → build/test → staging → prod (manual gate)
```

---

## 3. Environments

| Env | Purpose | Data | Deploy |
|---|---|---|---|
| **local** | dev | SQLite/local Postgres, AI stubs | manual |
| **staging** | integration + QA | Postgres (seeded), real AI (test keys) | auto on merge to `main` |
| **production** | live users | Postgres HA, real everything | manual gate from staging |

---

# THE PHASES

> Effort is in **person-weeks (pw)** assuming the 4–6 person team.
> Phases 1–3 are the true "make it not break" foundation and should not be skipped.

---

## Phase 0 · Stabilize the MVP  ·  ~1 week
**Goal:** the current app actually runs, end-to-end, on a real device against a deployed backend. This is the bridge from "compiles" to "works".

**Tasks**
- Run on physical Android device; fix camera/mic/permission issues (Android manifest perms for camera, mic, internet)
- Validate real Gemini path with a key (`test_gemini.py`) — voice, text, pricing
- Deploy backend to Render/Railway (staging), point app at it
- Basic error toasts on every network call (no silent failures)
- Seed script: 6 demo artisans + products with real images
- Smoke-test the full journey on device 5× in a row

**Deliverables:** installable APK + live staging API + demo data.
**Exit:** a non-developer can install the APK and complete photo→listing→price→publish→inquiry without a crash.

---

## Phase 1 · Security & Auth Foundations  ·  ~2 weeks  🔴 critical
**Goal:** no embarrassing security holes; real identity.

**Tasks**
- **Real OTP** via SMS provider (MSG91 / Twilio / Gupshup); remove hardcoded `123456`; store OTP in Redis with TTL + attempt limits
- **Rate limiting** (slowapi / gateway) on auth + AI + upload endpoints
- **Upload hardening:** max size, MIME/type allowlist, re-encode images, reject on failure
- Tighten **CORS** to known origins; shorten JWT TTL + refresh tokens; rotate secret
- **Secrets manager** (Render/AWS/Doppler) — nothing in git
- Input validation everywhere (Pydantic strict), consistent error envelope
- Security headers, HTTPS-only, disable server banner
- **Threat model** doc + fix top risks

**Exit:** OWASP top-10 quick audit passes; no secret in repo; auth abuse rate-limited.

---

## Phase 2 · Data Layer & Infrastructure  ·  ~2 weeks  🔴 critical
**Goal:** durable, migratable, restart-safe backend.

**Tasks**
- Migrate **SQLite → managed Postgres** (Supabase/RDS); connection pooling
- **Alembic migrations** — schema versioned, no more `create_all`
- **Object storage** for images (Cloudinary/S3) + signed URLs; stop serving from local disk
- **Redis** + **Celery** for AI jobs — durable queue, retries, dead-letter, survives restart (replace `BackgroundTasks`)
- Job status model (`queued/running/done/failed`) exposed to app; app polls or gets push
- **Backups**: automated DB snapshots + a *tested* restore runbook
- Config per-environment; `.env` → typed settings validated at boot
- Dockerize backend + `docker-compose` for local parity

**Exit:** kill the API mid-AI-job → job still completes after restart; DB restore rehearsed.

---

## Phase 3 · Productionize the AI  ·  ~2–3 weeks  🔴 core value
**Goal:** the 3 AI features are reliable, cheap, and genuinely good.

**Tasks**
- **Gemini reliability:** timeouts, retries w/ backoff, circuit breaker, graceful fallback to stub/typed-input; structured-output validation + repair
- **Cost control:** per-user quotas, response caching, cheapest-model routing, monthly budget alerts
- **Image (F1):** productionize rembg (worker w/ model cached) OR Cloudinary AI; consistent 1:1 white-bg output; quality QA on real craft photos (textiles/pottery/jewellery)
- **Voice (F2):** test across Hindi + 3–4 regional languages; handle noisy/low-quality audio; confidence + let user re-record; store transcript for trust
- **Pricing (F3):** replace 15-row CSV with a **real comparables dataset** (scrape/curate Amazon Karigar, Meesho, Etsy, GeM — few thousand rows); retrain + validate error; keep reasoning honest & explainable
- **Prompt/versioning:** version prompts, eval set of sample inputs, regression check on prompt changes
- Abuse/safety: block non-product audio/images, content moderation

**Exit:** 50 real craft samples → ≥90% produce a usable listing + sensible price; AI outage degrades gracefully, never 500s the app.

---

## Phase 4 · Commerce Core  ·  ~3–4 weeks
**Goal:** it's a real marketplace, not just a catalog.

**Tasks**
- **Buyer accounts** (separate role): registration, org/GSTIN verification, buyer auth
- **Inquiry → negotiation → order** lifecycle; order states; artisan accept/reject
- **Payments**: Razorpay/UPI integration OR route through GeM/ONDC settlement; escrow consideration
- **Logistics** hooks (Shiprocket/Delhivery) or manual fulfilment tracking
- Artisan **dashboard**: views, inquiries, orders, earnings
- Notifications: push (FCM) + SMS/WhatsApp for inquiries/orders
- Ratings & reviews; dispute/return basics

**Exit:** a buyer can discover → inquire → order → pay → track, and the artisan gets paid & notified.

---

## Phase 5 · Govt & Market Linkage Integrations  ·  ~3–4 weeks (parallelizable)
**Goal:** the differentiators that matter for a MoSJE product.

**Tasks**
- **ONDC** onboarding (seller-app role): catalog publish, search, order protocol — start in ONDC staging
- **GeM** seller integration / assisted listing (per GeM API availability)
- **Bhashini** as the govt language layer (swap/augment Gemini for STT/MT) — provider-agnostic switch already scaffolded
- **DigiLocker / Aadhaar-based** artisan verification (optional, for trust + subsidy linkage)
- Map to MoSJE beneficiary schemes / cluster data if data-sharing MoU exists

**Exit:** at least ONDC staging catalog live; Bhashini pluggable in prod config.
**Note:** govt API access has lead time — **start paperwork in Phase 1**.

---

## Phase 6 · Quality, Testing & CI/CD  ·  ~2 weeks (runs alongside 1–4)
**Goal:** change safely and fast.

**Tasks**
- Backend: **pytest** unit + integration (auth, products, AI orchestration, pricing) → >70% on critical paths
- Flutter: widget + golden tests for key screens; integration test for the hero flow
- **CI (GitHub Actions):** lint + analyze + tests + build on every PR; block merge on red
- **CD:** auto-deploy to staging on merge; one-click prod promote; DB migration step
- Contract test app ↔ backend against `openapi.yaml`
- Load test (Locust/k6) to target concurrency; fix bottlenecks
- Rollback runbook + feature flags for risky features

**Exit:** every PR gated by green CI; a bad deploy can be rolled back in <5 min.

---

## Phase 7 · Observability & Ops  ·  ~1–2 weeks (alongside)
**Goal:** know when it breaks, before users tell you.

**Tasks**
- **Sentry** (backend + Flutter) for errors + release tracking
- Structured logging (JSON) → Loki/CloudWatch; request tracing/correlation IDs
- Metrics (Prometheus/Grafana): latency, error rate, AI cost/latency, queue depth, DAU
- **Alerting** on SLO breaches (error rate, p95 latency, queue backlog, AI budget)
- Health `/livez` + `/readyz`; uptime monitor (UptimeRobot)
- Cost dashboard (infra + AI); anomaly alerts
- Analytics (privacy-respecting): funnel from install → first listing → first sale

**Exit:** an induced error pages on-call within minutes with a traceable root cause.

---

## Phase 8 · Compliance, Accessibility & Legal  ·  ~2–3 weeks  🔴 for govt
**Goal:** a govt-grade, lawful, inclusive product.

**Tasks**
- **DPDP Act 2023**: consent flow, data-processing notice, data-access/erasure, retention policy, data localization
- **Privacy policy + Terms** (legal review); grievance officer contact (IT Rules)
- **Accessibility**: WCAG-aligned — TalkBack/screen-reader, large-text, contrast, full voice-navigation for low-literacy users; usability testing with *actual* artisans
- **Security audit / VAPT** by a third party (often required for govt); fix findings
- PII encryption at rest; access logging; least-privilege roles
- Play Store data-safety + content policies; app signing

**Exit:** external security audit passed; DPDP + accessibility checklist signed off; legal docs live.

---

## Phase 9 · Pilot, Scale & Launch  ·  ~2–3 weeks + ongoing
**Goal:** prove it with real artisans, then scale.

**Tasks**
- **Closed pilot**: 20–50 artisans in 1–2 clusters; on-ground onboarding + feedback loop
- Fix top pilot issues; measure activation & first-sale rate
- Autoscaling + CDN + DB read-replicas as load grows
- Field-support playbook (multilingual help, video guides, IVR/WhatsApp support)
- Staged public rollout (region by region); Play Store launch
- KPI review cadence; iterate

**Exit:** pilot artisans making real sales; metrics green; ready to widen.

---

## 4. Sequencing & rough timeline

```
Month 1   ██ P0 stabilize
          ████ P1 security ─┐
          ████ P2 data/infra ┼─ foundation (do first, mostly parallel)
Month 2   ██████ P3 AI productionize
          ████ P6 testing/CI ── (starts here, continues)
          ██ P7 observability
Month 3   ████████ P4 commerce core
          ██████ P5 ONDC/GeM/Bhashini (paperwork started M1)
Month 4   ██████ P8 compliance/accessibility/audit
          ██████ P9 pilot → scale → launch
```

**Realistic total:** ~**3.5–4.5 months** with a focused 4–6 person team to a real pilot launch. Foundation (P0–P3) ≈ 6–8 weeks and gets you a genuinely solid, safe product even before commerce depth.

**Effort rollup (approx):** P0 ~1pw · P1 ~2pw · P2 ~2pw · P3 ~2.5pw · P4 ~3.5pw · P5 ~3.5pw · P6 ~2pw · P7 ~1.5pw · P8 ~2.5pw · P9 ~2.5pw → **~23 person-weeks** (overlapping across the team).

---

## 5. Team ownership (RACI-lite)

| Area | Owner |
|---|---|
| Mobile (Flutter, a11y, offline) | Mobile Lead + 1 |
| Backend, data, infra, security | Backend Lead |
| AI/ML (Gemini, pricing data, evals) | AI/ML |
| DevOps/CI/observability | Backend Lead or dedicated |
| ONDC/GeM/Bhashini + compliance paperwork | PM (+ backend for integration) |
| QA, testing, pilot ops | PM + rotating |

---

## 6. Risk register (top)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Govt API (ONDC/GeM/Bhashini) onboarding delay | High | High | Start paperwork Phase 1; keep provider-agnostic; simulate until live |
| AI cost blows up at scale | Med | High | Quotas, caching, cheap-model routing, budget alerts (P3/P7) |
| Low artisan adoption (literacy/trust) | Med | High | Voice-first a11y, field onboarding, pilot feedback (P8/P9) |
| Payment/settlement complexity | Med | High | Prefer routing via ONDC/GeM settlement over building escrow |
| Security incident (govt PII) | Low | Severe | Phase 1 + Phase 8 audit, encryption, least privilege |
| Pricing accuracy questioned | Med | Med | Real dataset + honest, explainable reasoning (P3) |
| Team bandwidth / scope creep | High | Med | Phase gates, feature flags, "foundation before features" |

---

## 7. Immediate next actions (this week)

1. **P0**: run on a real device + validate Gemini key + deploy staging + seed data
2. Start **govt API paperwork** (ONDC/GeM/Bhashini, SMS provider) — long lead time
3. Stand up **CI** (analyze + test on PR) — cheap, compounding value
4. Pick + provision managed **Postgres** and **Redis** for staging
5. Add **Sentry** to both apps (5-min win, huge visibility)

---

*Roadmap v1 · Living document — revise at each phase gate.*
*"Foundation before features. Every phase ships something real."*
