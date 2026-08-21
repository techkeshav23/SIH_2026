# KalaSetu — AI Market Linkage & Smart Cataloging for Artisans
### SIH 2026 · PS ID 26090 · MoSJE · Deep Execution Plan

> **Name idea:** *KalaSetu* (कलासेतु = "bridge for craft"). Alt: *Karigar*, *ShilpConnect*, *HunarHaat Digital*.
> Deadline: **20 Sep 2026** · Today: **21 Aug 2026** · Runway: **~4.3 weeks** · Team: **4–6**

---

## 1. The Winning Angle (padho isse pehle — ye scoring ka core hai)

Judges MoSJE ke hain — unko **social impact + govt-alignment + real working AI** chahiye, fancy tech nahi. Humara edge:

1. **Bhashini integration** (govt's own Indic language AI stack) — STT + translation ke liye. Ye "Digital India / Atmanirbhar" narrative ko directly hit karta hai. **Huge scoring point.**
2. **ONDC / GeM market linkage** — sirf "listing app" nahi, actual B2B network se connect. PS literally "government e-marketplaces" bolta hai.
3. **Offline-first + voice-first UX** — low-literacy artisan ke liye. Text minimal, icons + voice prompts maximum. Ye "accessibility" requirement ko demo mein dikhana.
4. **1-tap magic**: artisan photo kheenche → 30 sec mein professional listing (enhanced image + Hindi/English description + suggested price) taiyaar. **Yahi humara demo "wow moment" hai.**

**Elevator pitch:** *"KalaSetu artisan ke phone ko ek virtual business manager bana deta hai — voice bolo apni bhasha mein, photo kheencho, aur AI ready-to-sell professional listing bana ke seedha B2B buyers/GeM se jod deta hai."*

---

## 2. Scope — MoSCoW (1 month realistic)

### MUST (demo ke bina incomplete)
- **F1 · AI Image Studio**: capture → auto background removal → lighting/white-balance fix → e-commerce crop (square, clean/white bg) → before/after slider.
- **F2 · Voice Auto-Cataloger**: regional voice note → STT (Bhashini/Whisper) → translate → LLM generates SEO title + description in **English + Hindi**.
- **F3 · Pricing Assistant**: category + material cost input + image/desc signals → suggested price range with reasoning ("based on similar handloom sarees ₹X–₹Y").
- **F4 · Catalog & Product management**: create/edit/list products, offline draft + sync.
- **F5 · Minimalist accessible UI**: icon-driven, Hindi/English toggle, voice prompts, big tap targets.

### SHOULD
- **F6 · Buyer/Marketplace view**: B2B buyer browse + inquiry (simulated ONDC/GeM linkage).
- **F7 · Artisan profile + onboarding** (OTP login, story/craft type).
- **F8 · Dashboard**: views, inquiries, earnings estimate.

### COULD (agar time bache)
- WhatsApp share of listing, analytics, ratings, order/logistics stub.

### WON'T (v1) — scope creep se bacho
- Real payments/escrow, real ONDC production onboarding, delivery/logistics, seller KYC verification.

---

## 3. System Architecture

```
┌──────────────────────────┐        ┌─────────────────────────────┐
│   Flutter App (Android)  │  HTTPS │   FastAPI Backend (async)   │
│  - Camera / Studio       │◄──────►│   - Auth (JWT/OTP)          │
│  - Voice recorder        │  REST  │   - Products / Catalog CRUD │
│  - Riverpod state        │        │   - Orchestrates AI calls   │
│  - Hive offline cache    │        │   - Pricing engine          │
│  - i18n (hi/en)          │        └──────┬──────────┬───────────┘
└──────────────────────────┘               │          │
                                    ┌───────▼──┐   ┌───▼──────────────┐
                                    │ Postgres │   │ Object Storage   │
                                    │ (Supabase│   │ (Cloudinary/S3)  │
                                    │  or RDS) │   │  images          │
                                    └──────────┘   └──────────────────┘
                                            │
                    ┌───────────────────────┼────────────────────────┐
                    ▼                        ▼                        ▼
          ┌─────────────────┐    ┌──────────────────────┐   ┌─────────────────┐
          │ Image AI        │    │ Language AI          │   │ Pricing AI      │
          │ rembg / remove  │    │ Bhashini STT+MT      │   │ heuristic + ML  │
          │ .bg / Cloudinary│    │ Whisper (fallback)   │   │ regression on   │
          │ + PIL post-proc │    │ LLM (Gemini/Claude)  │   │ comparables     │
          └─────────────────┘    └──────────────────────┘   └─────────────────┘
```

**Async job pattern:** AI calls slow ho sakte hain → FastAPI `BackgroundTasks` (ya Celery+Redis agar team comfortable) se process karo, app polls `GET /products/{id}` for status (`processing → ready`). Demo ke liye BackgroundTasks kaafi hai.

---

## 4. Tech Stack (final)

| Layer | Choice | Why |
|---|---|---|
| Mobile | **Flutter 3.x + Dart**, Riverpod, GoRouter | cross-platform, best camera/voice plugins |
| Local DB | **Hive** (or Isar) | offline drafts + sync |
| Backend | **Python FastAPI + Uvicorn**, Pydantic v2 | async, fast to build, great for AI orchestration |
| DB | **PostgreSQL** (Supabase free tier — bhi auth+storage deta hai) | relational, hosted, zero-ops |
| Image store | **Cloudinary** (free tier, has AI bg-removal built-in!) | double-duty: storage + enhancement |
| Image AI | Cloudinary AI bg-removal **or** `rembg` (self-host) + Pillow post | reliable, real |
| STT + Translate | **Bhashini APIs** (primary, govt) + **OpenAI Whisper** fallback | Indic langs, govt-aligned |
| Text gen | **Gemini 1.5 Flash** or **Claude Haiku** (cheap, fast) | SEO description EN+HI |
| Pricing | Python: rules + scikit-learn `RandomForest`/`LinearRegression` on seed comparables CSV | "functional ML" without needing huge dataset |
| Auth | JWT + phone OTP (Firebase Auth or Supabase) | simple, mobile-friendly |
| Hosting | Backend → **Render/Railway**; DB → Supabase | free tiers, quick deploy |
| Deploy demo | Android APK (sideload) — no Play Store needed for SIH | fastest |

**Keys/accounts needed early (Day 1-2 task):** Bhashini ULCA account, Cloudinary, Gemini/Anthropic API key, Supabase project. *Sabse bada schedule risk — turant register karo.*

---

## 5. Data Model (Postgres core tables)

```
users        (id, phone, name, language_pref, craft_type, region, created_at)
products     (id, user_id, title_en, title_hi, desc_en, desc_hi,
              category, material, status[draft|processing|ready|listed],
              suggested_price_min, suggested_price_max, final_price,
              raw_image_url, enhanced_image_url, created_at, updated_at)
voice_notes  (id, product_id, audio_url, transcript_raw, transcript_lang, translated_en)
price_signals(id, product_id, model_price, comparables_json, reasoning)
inquiries    (id, product_id, buyer_id, message, status, created_at)   # B2B linkage
buyers       (id, org_name, gstin, type[GeM|B2B|retail])
```

---

## 6. AI Features — Deep Dive (yahi differentiator hai)

### F1 · AI Image Studio
**Pipeline:** capture (Flutter `camera`) → upload raw → backend:
1. Background removal — Cloudinary `e_background_removal` **or** `rembg` (U²-Net).
2. Composite onto clean white/gradient bg.
3. Auto lighting/contrast/white-balance — Pillow `ImageEnhance` + simple histogram stretch.
4. Center-crop to 1:1, resize 1080×1080, sharpen.
5. Return `enhanced_image_url`.
**Demo flourish:** before/after slider in app. **Hero feature #1.**
**Fallback:** agar API down → local `rembg` container.

### F2 · Voice Auto-Cataloger  ← **star of the show**
**Pipeline:** record (Flutter `record`) → upload audio → backend:
1. STT via **Bhashini ASR** (Hindi/Bhojpuri/Tamil/etc.) → raw transcript.
2. Translate to English via **Bhashini NMT** (or keep, Whisper handles many).
3. LLM prompt → structured JSON: `{title_en, title_hi, description_en, description_hi, category, tags, materials}`. SEO-optimized, e-commerce tone.
4. Save, show editable in app (artisan can voice-confirm).
**Prompt design:** system prompt = "You are an e-commerce copywriter for Indian handmade crafts. Given a rough artisan description, produce a professional, SEO-friendly listing. Keep authentic cultural terms. Output strict JSON."
**Fallback:** Whisper (openai/local) for STT if Bhashini flaky; typed input path bhi rakho.

### F3 · Dynamic Pricing Assistant
**Approach (functional, honest ML):**
- Seed a `comparables.csv` (category, material, size, region → price) scraped/hand-built (~200-500 rows from Amazon/Meesho/Etsy handloom listings).
- Train `RandomForestRegressor` → predict base price from features (category, material, dimensions).
- Adjust: + material cost (artisan input) + margin band → output **range + reasoning string**.
- Show comparables ("5 similar products ₹450–₹800").
**Honesty for judges:** "trend-aware suggestion" — clearly explain it's heuristic+ML on comparable market data, not magic. Judges respect honest scoping.

---

## 7. Team Split (4–6 members)

| Role | Owner | Responsibilities |
|---|---|---|
| **A · Mobile Lead** | 1 | Flutter architecture, camera+voice modules, Studio UI, offline sync |
| **B · Mobile/UI** | 1 | UI/UX build, i18n hi/en, accessibility, catalog + dashboard screens |
| **C · Backend Lead** | 1 | FastAPI, DB schema, auth, product/catalog APIs, deploy |
| **D · AI/ML** | 1 | Image pipeline, Bhashini/Whisper + LLM cataloger, pricing model |
| **E · UI/UX + Data** | 1 (if 5) | Figma design system, comparables dataset, demo assets, content |
| **F · PM/Docs/Demo** | 1 (if 6) | Pitch deck, demo script, video, docs, integration testing, QA |

*Agar 4 log:* merge E+F into A/D. Backend+AI ek insaan pe zyada load — prioritize.

**Parallelization key:** Day 1 pe **API contract (OpenAPI spec) freeze karo** taaki mobile & backend independently chalein. Mock server (FastAPI stub) se mobile team blocked na ho.

---

## 8. Timeline — 4 Sprints (Aug 21 → Sep 20)

### Sprint 0 · Setup (Aug 21–24) — 3-4 din
- [ ] Repo init (monorepo: `/app`, `/backend`, `/ml`, `/docs`), git, branch strategy
- [ ] All accounts/keys: Bhashini, Cloudinary, Gemini/Anthropic, Supabase ← **critical path**
- [ ] Figma wireframes (onboarding, home, studio, cataloger, pricing, catalog)
- [ ] **Freeze OpenAPI contract** + Postgres schema
- [ ] Flutter skeleton + navigation; FastAPI skeleton + `/health`
- [ ] CI-lite: format/lint, one deploy to Render (backend hello-world)

### Sprint 1 · Core Rails (Aug 25 – Sep 3) — end-to-end thin slice
- [ ] Auth (OTP) + onboarding flow
- [ ] Product CRUD (create draft, list, detail) — mobile ↔ backend working
- [ ] Camera capture + raw upload to Cloudinary
- [ ] **F1 Image Studio pipeline** working (bg removal + enhance + before/after)
- [ ] Offline draft + sync (Hive)
- [ ] **Milestone:** artisan can create a product with an enhanced photo. Demo-able.

### Sprint 2 · The AI Magic (Sep 4 – Sep 12)
- [ ] **F2 Voice Cataloger** full: record → Bhashini STT → translate → LLM → EN+HI listing
- [ ] **F3 Pricing** model trained + API + UI
- [ ] i18n complete (hi/en), voice prompts, accessibility polish
- [ ] **F6 Buyer view** + inquiry flow (simulated ONDC/GeM)
- [ ] Dashboard (views/inquiries)
- [ ] **Milestone:** full "photo+voice → listing → priced → discoverable" loop.

### Sprint 3 · Polish, Demo, Submit (Sep 13 – Sep 20)
- [ ] Bug bash + QA on real device, edge cases (no internet, API fail → fallbacks)
- [ ] UI polish, animations, empty/loading/error states
- [ ] Seed demo data (5-6 beautiful sample artisans/products)
- [ ] **Pitch deck** (problem→solution→impact→tech→scale) + architecture diagram
- [ ] **Demo video** (2-3 min) + rehearse live demo script
- [ ] Build signed APK; docs/README; submit on SIH portal
- [ ] **Buffer: Sep 18-20** for surprises. Don't code new features here.

> **Rule:** Har sprint ke end pe ek *deployable, demo-able* build hona chahiye. "Always shippable."

---

## 9. Repo Structure (monorepo)

```
kalasetu/
├── app/                 # Flutter
│   ├── lib/
│   │   ├── core/        # theme, i18n, router, network
│   │   ├── features/    # auth, studio, cataloger, pricing, catalog, buyer
│   │   ├── data/        # models, repositories, hive
│   │   └── main.dart
│   └── pubspec.yaml
├── backend/             # FastAPI
│   ├── app/
│   │   ├── api/         # routers: auth, products, ai, pricing, buyers
│   │   ├── services/    # image_ai, language_ai, pricing_engine
│   │   ├── models/      # SQLAlchemy + Pydantic schemas
│   │   ├── core/        # config, db, security
│   │   └── main.py
│   └── requirements.txt
├── ml/                  # pricing model training, comparables.csv, notebooks
├── docs/                # openapi.yaml, architecture.md, pitch-deck, demo-script
└── PLAN.md
```

---

## 10. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Bhashini API access delay/flaky | High | Register Day 1; **Whisper fallback** ready; typed-input path always |
| AI latency ruins demo | High | Async + polling; pre-warm; cache demo products; show progress UI |
| Pricing "AI" looks fake | Med | Honest framing + real comparables dataset + reasoning string |
| Scope creep | High | MoSCoW discipline; WON'T list; Sprint 3 = no new features |
| Team member blocked on API | Med | Freeze contract Day 1 + mock server |
| Cross-platform iOS untested | Low | Demo on Android APK; note iOS-ready (Flutter) |
| Internet-dependent in rural context | Med | Offline-first drafts; queue-and-sync; highlight in pitch |

---

## 11. Judging / Demo Strategy (mat bhoolna — ye 40% marks)

1. **Open with the human story** — Kamla devi, weaver, Surajkund ke baad saal bhar koi sale nahi. 20 sec.
2. **Live demo the 30-sec magic**: bolo Hindi mein → photo → *boom* professional listing + price. Ye judges ko hila dega.
3. **Show govt-alignment**: Bhashini logo, ONDC/GeM linkage, "Digital India" framing.
4. **Impact numbers**: reduce dependency on fairs, X% income uplift potential, N artisans scalable.
5. **Architecture slide**: scalable, cloud, secure — shows engineering depth.
6. **Close with scale**: "MoSJE ke 50 lakh+ beneficiaries" reach.

**Deliverables checklist for submission:** working APK · GitHub repo · pitch deck (PDF) · demo video · this technical doc.

---

## 12. Immediate Next Actions (aaj/kal)

1. **Naam final karo** (KalaSetu?) + team roles assign.
2. **Sab accounts register** (Bhashini sabse pehle — approval mein time lagta hai).
3. Main repo scaffold kar deta hoon (Flutter + FastAPI skeleton + OpenAPI contract) — bolo toh abhi shuru karun.
4. Figma wireframes start (UI person).

---
*Plan v1 · Iterate as we build. Questions/changes — bolo, update kar dunga.*
