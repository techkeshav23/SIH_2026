# Slide 6 — Feasibility & Viability

## Why it is feasible
- Built on **proven, scalable technology** (Flutter, FastAPI, Google Vertex AI, PostgreSQL).
- A **working cross-platform app** already exists with a **fully functional offline demo**.
- **Low barrier to use:** voice + icons + read-aloud make it usable by **low-literacy** artisans;
  runs on **low-end phones** and in **poor connectivity** (offline-first).

## Potential challenges & risks
- Government API onboarding (**ONDC / GeM / Bhashini**) can take time.
- **Rural connectivity** is unreliable.
- **AI usage cost** can grow at large scale.
- **Adoption & trust** among first-time digital users.

## Strategies to overcome (our mitigations)
- **Provider-agnostic, pluggable design** — the app runs and demos even before govt APIs are live.
- **Offline-first with queue-and-sync** — drafts and actions save locally and upload when online.
- **Cost control** — response caching, per-user quotas, and cheaper AI-model routing.
- **Trust & onboarding** — voice-guided first-run, IVR/toll-free help, and the artisan's own story on their shop page.

**Speaker note:**
"It's realistic because it already works. Our design assumes weak internet and govt-API delays,
so the app is useful from day one and only gets stronger as integrations go live."
