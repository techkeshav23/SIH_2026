import os

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api import (
    ai,
    auth,
    buyer_auth,
    buyers,
    community,
    dashboard,
    orders,
    pricing,
    products,
    promote,
    quotes,
    voice,
)
from app.core.config import settings
from app.core.db import init_db
from app.core.observability import RequestIdMiddleware, init_sentry, setup_logging

setup_logging()
init_sentry()

app = FastAPI(
    title="KalaSetu API",
    description="AI Market Linkage & Smart Cataloging for Artisans (SIH 26090)",
    version="0.1.0",
)

app.add_middleware(RequestIdMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def security_headers(request: Request, call_next):
    resp = await call_next(request)
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["X-Frame-Options"] = "DENY"
    resp.headers["Referrer-Policy"] = "no-referrer"
    if not settings.is_dev:
        resp.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return resp


# ---- consistent error envelope: {"error": {"code", "message"}} ----
@app.exception_handler(StarletteHTTPException)
async def _http_exc(request: Request, exc: StarletteHTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": exc.status_code, "message": exc.detail}},
        headers=getattr(exc, "headers", None),
    )


@app.exception_handler(RequestValidationError)
async def _validation_exc(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={"error": {"code": 422, "message": "Validation error", "details": exc.errors()}},
    )


def _warm_rembg():
    from app.services import image_ai

    image_ai.warmup()


@app.on_event("startup")
def _startup():
    init_db()
    # Prime google-genai in THIS (main) thread — see ai_client.warmup(). Without it
    # the first Gemini call from a worker thread fails and listings fall back to the
    # stub. Runs once at startup; best-effort.
    from app.services import ai_client

    ai_client.warmup()
    # Warm the background-removal model in a background thread so container
    # startup/readiness isn't blocked but the first enhance is already fast.
    if settings.use_rembg:
        import threading

        threading.Thread(target=_warm_rembg, daemon=True).start()


@app.get("/health", tags=["auth"])
def health():
    return {"status": "ok"}


@app.get("/livez", tags=["auth"])
def livez():
    return {"status": "alive"}


@app.get("/readyz", tags=["auth"])
def readyz():
    # In prod, check DB/Redis connectivity here.
    return {"status": "ready"}


@app.get("/warmup", tags=["auth"])
def warmup():
    """Run one tiny rembg inference to keep the ONNX session hot. A Cloud Scheduler
    cron pings this every few minutes so a freshly (re)started instance is never
    cold (~90s first inference) when a real /ai/enhance-image arrives."""
    if not settings.use_rembg:
        return {"warm": False, "reason": "rembg disabled"}
    import time as _t

    from app.services import image_ai

    t0 = _t.perf_counter()
    image_ai.warmup()
    return {"warm": True, "ms": int((_t.perf_counter() - t0) * 1000)}


app.include_router(auth.router)
app.include_router(products.router)
app.include_router(ai.router)
app.include_router(pricing.router)
app.include_router(buyers.router)
app.include_router(buyer_auth.router)
app.include_router(orders.router)
app.include_router(dashboard.router)
app.include_router(community.router)
app.include_router(quotes.router)
app.include_router(voice.router)
app.include_router(promote.router)

# Product images: durable GCS (private bucket, streamed back here) in prod, or
# the local disk in dev/demo.
if settings.gcs_bucket:
    @app.get("/uploads/{filename}", tags=["media"])
    def serve_upload(filename: str):
        from app.core import gcs

        data = gcs.get_image(filename)
        if data is None:
            raise HTTPException(status_code=404, detail="Image not found")
        return Response(content=data, media_type="image/jpeg",
                        headers={"Cache-Control": "public, max-age=86400"})
else:
    _uploads = os.path.join(os.path.dirname(__file__), "..", "uploads")
    os.makedirs(_uploads, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=_uploads), name="uploads")
