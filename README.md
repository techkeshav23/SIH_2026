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

### API contract
See [docs/openapi.yaml](docs/openapi.yaml) — the frozen contract both mobile & backend build against.

---

## Tech stack

**Mobile:** Flutter · Riverpod · GoRouter · Hive (offline) · easy_localization
**Backend:** FastAPI · SQLAlchemy · Pydantic v2 · Postgres (Supabase)
**AI:** Bhashini (STT/translate) · Cloudinary/rembg (image) · Gemini/Claude (copy) · scikit-learn (pricing)

## Team

See [PLAN.md §7](PLAN.md) for role split (Mobile ×2, Backend, AI/ML, UI/UX, PM/Demo).
