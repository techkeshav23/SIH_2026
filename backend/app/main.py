import os

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api import ai, auth, buyer_auth, buyers, dashboard, orders, pricing, products
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


@app.on_event("startup")
def _startup():
    init_db()


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


app.include_router(auth.router)
app.include_router(products.router)
app.include_router(ai.router)
app.include_router(pricing.router)
app.include_router(buyers.router)
app.include_router(buyer_auth.router)
app.include_router(orders.router)
app.include_router(dashboard.router)

_uploads = os.path.join(os.path.dirname(__file__), "..", "uploads")
os.makedirs(_uploads, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=_uploads), name="uploads")
