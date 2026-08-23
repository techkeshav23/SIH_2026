# Slide 4 — Technical Approach

## Technologies used (all implemented in our build)
- **Mobile app:** Flutter (single codebase for **Android + iOS**), Riverpod state management, offline-first storage.
- **Backend:** Python **FastAPI**, PostgreSQL database, **Celery + Redis** for async AI jobs, containerized with **Docker**, Alembic migrations.
- **AI — Language & Cataloging:** Google **Vertex AI (Gemini)** hosted in **asia-south1 (Mumbai)** for Indian **data residency** — turns a voice note into an SEO listing in English + Hindi.
- **AI — Image:** background removal + auto-enhancement (rembg / Pillow) → e-commerce-grade photos.
- **AI — Pricing:** **scikit-learn** ML model + real market comparables → fair price range with reasoning.
- **Govt & Language stack:** **Bhashini**-ready (Indic speech/translation) · **ONDC / GeM** market linkage (pluggable).
- **Security & Access:** OTP + JWT auth, rate limiting; **read-aloud TTS**, large-text mode, Hindi/English.

## Methodology / process flow
```
Photo ─► AI Image Studio ─► Voice/Text ─► AI Auto-Cataloger (EN+HI) ─► ML Pricing ─► Publish ─► B2B / ONDC-GeM buyers
```

## Why this stack
- **Scalable & proven** (Flutter + FastAPI + managed cloud), **India-resident AI**, and **govt-aligned**
  (Bhashini, ONDC/GeM, Digital India) — production-ready architecture, not just a prototype.

**Speaker note:**
"We use Google's Vertex AI (in India) for the language intelligence, machine learning for
pricing, and Flutter + FastAPI for a scalable, cross-platform product that fits govt standards."
