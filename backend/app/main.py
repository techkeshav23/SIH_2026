import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api import ai, auth, buyers, pricing, products
from app.core.db import init_db

app = FastAPI(
    title="KalaSetu API",
    description="AI Market Linkage & Smart Cataloging for Artisans (SIH 26090)",
    version="0.1.0",
)

# Open CORS for hackathon dev (mobile app + web). Tighten in prod.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def _startup():
    init_db()


@app.get("/health", tags=["auth"])
def health():
    return {"status": "ok"}


app.include_router(auth.router)
app.include_router(products.router)
app.include_router(ai.router)
app.include_router(pricing.router)
app.include_router(buyers.router)

# serve enhanced images locally (prod uses Cloudinary/S3 URLs)
_uploads = os.path.join(os.path.dirname(__file__), "..", "uploads")
os.makedirs(_uploads, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=_uploads), name="uploads")
