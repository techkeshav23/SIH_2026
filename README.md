# KalaSetu — AI Market Linkage & Smart Cataloging for Artisans

> **SIH 2026 · PS ID 26090 · Ministry of Social Justice & Empowerment (MoSJE)**

A cross-platform mobile app that acts as a **virtual business manager** for marginalized
artisans — turning a voice note + a photo into a professional, priced, ready-to-sell
e-commerce listing, and connecting them to B2B buyers / government e-marketplaces.

📋 Full execution plan: [PLAN.md](PLAN.md)

---

## Monorepo layout

```
kalasetu/
├── app/        # Flutter mobile app (Android/iOS)
├── backend/    # FastAPI backend + AI orchestration
├── ml/         # Pricing model training + comparables dataset
├── docs/       # OpenAPI contract, architecture, pitch, demo script
└── PLAN.md     # Deep execution plan
```

## Core features

| # | Feature | Status |
|---|---------|--------|
| F1 | AI Image Studio — bg removal, lighting fix, e-commerce crop | 🟡 scaffold |
| F2 | Voice Auto-Cataloger — regional voice → SEO listing (EN+HI) | 🟡 scaffold |
| F3 | Dynamic Pricing Assistant — ML + comparables → price range | 🟡 scaffold |
| F4 | Catalog & product management (offline-first) | 🟡 scaffold |
| F5 | Minimalist, accessible, voice-first UI (hi/en) | 🟡 scaffold |

---

## Quick start

### Backend
```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows (PowerShell: .venv\Scripts\Activate.ps1)
pip install -r requirements.txt
cp .env.example .env          # then fill keys
uvicorn app.main:app --reload
# → http://localhost:8000/docs  (interactive API)
```

### Mobile app
```bash
cd app
flutter pub get
flutter run
```

### Tests
```bash
cd backend && .venv\Scripts\python.exe -m pytest -q     # 27 tests
```

### Production-like stack (Docker)
```bash
docker compose up --build        # API + Celery worker + Postgres + Redis
# API → http://localhost:8000/docs
```
Migrations run automatically (`alembic upgrade head`) on API start. To create a
new migration after changing models: `cd backend && alembic revision --autogenerate -m "msg"`.

### API contract
See [docs/openapi.yaml](docs/openapi.yaml) — the frozen contract both mobile & backend build against.

---

## Tech stack

**Mobile:** Flutter · Riverpod · GoRouter · Hive (offline) · easy_localization
**Backend:** FastAPI · SQLAlchemy · Pydantic v2 · Postgres (Supabase)
**AI:** **Vertex AI** (Gemini models — voice→listing multimodal · pricing reasoning) · rembg/Pillow (image) · scikit-learn (pricing)

### Enabling real AI (Vertex AI)
1. Create/select a GCP project and **enable the Vertex AI API**.
2. Authenticate (dev): `gcloud auth application-default login`
   (server: set `GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json`)
3. In `backend/.env`: `USE_REAL_AI=true`, `USE_VERTEX=true`, `GCP_PROJECT=<id>`, `GCP_LOCATION=asia-south1`
4. Verify: `cd backend && .venv\Scripts\python.exe check_ai.py`

Vertex AI is preferred for prod/govt (IAM auth, India data residency in Mumbai).
Set `USE_VERTEX=false` + `GEMINI_API_KEY` to use the simpler Gemini Developer API instead.
Without either, everything still runs on functional **stubs** (great for offline dev).
The language layer is provider-agnostic — Bhashini can be plugged in later too.

## Team

See [PLAN.md §7](PLAN.md) for role split (Mobile ×2, Backend, AI/ML, UI/UX, PM/Demo).
