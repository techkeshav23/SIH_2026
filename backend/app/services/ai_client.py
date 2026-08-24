"""Single place that builds the Google GenAI client.

The `google-genai` SDK serves the SAME Gemini models via two backends:
  - **Vertex AI** (google Cloud, enterprise): auth via GCP project + ADC /
    service account, data residency (e.g. asia-south1 / Mumbai). Preferred for
    govt / production deployment.
  - **Gemini Developer API**: simple API key (dev convenience / fallback).

Switch with USE_VERTEX. When AI isn't configured (or USE_REAL_AI=false), callers
fall back to functional stubs so the app always runs.
"""
from app.core.config import settings

TIMEOUT_MS = 30_000


def ai_enabled() -> bool:
    if not settings.use_real_ai:
        return False
    if settings.use_vertex:
        return bool(settings.gcp_project)
    return bool(settings.gemini_api_key)


def warmup() -> bool:
    """Prime google-genai in the MAIN thread at startup.

    google-genai 2.x lazily initializes a shared HTTP transport on first use. If
    that first use lands in a worker thread (FastAPI runs sync endpoints and eager
    Celery tasks in a threadpool), every call fails with 'client has been closed'
    and the listing silently degrades to the stub. Making one call from the main
    thread here initializes the transport correctly so the threadpool calls work.
    """
    import logging
    import time

    log = logging.getLogger("kalasetu.ai")
    if not ai_enabled():
        return False
    for attempt in range(3):
        try:
            client = build_client()  # hold a strong ref (see build_client note)
            client.models.generate_content(model=settings.gemini_model, contents="hi")
            log.info("genai warmup ok (attempt %d)", attempt + 1)
            return True
        except Exception as e:  # noqa: BLE001
            log.warning("genai warmup attempt %d failed: %s", attempt + 1, str(e)[:80])
            time.sleep(2 * (attempt + 1))
    log.error("genai warmup failed — listings may fall back to stub")
    return False


def build_client():
    """Construct a genai.Client for Vertex AI (or the Developer API fallback).

    IMPORTANT: the caller MUST hold this client in a local variable for the whole
    request. google-genai's httpx client closes itself in __del__, so if the client
    is a throwaway expression (e.g. build_client().models.generate_content(...)) it
    can be garbage-collected mid-call — the transport then closes and the request
    fails with 'client has been closed'. This bit only on prod (Cloud Run GC is more
    eager than a local dev box), which is why listings silently fell back to stubs.
    """
    from google import genai
    from google.genai import types

    # Also disable google-genai's INTERNAL retry (it closes the client on a retryable
    # error and masks the real one); our own _with_retry handles retries.
    http = types.HttpOptions(timeout=TIMEOUT_MS, retry_options=types.HttpRetryOptions(attempts=1))
    if settings.use_vertex:
        # Auth via Application Default Credentials:
        #   gcloud auth application-default login   (dev)
        #   or GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json   (server)
        return genai.Client(
            vertexai=True,
            project=settings.gcp_project,
            location=settings.gcp_location,
            http_options=http,
        )
    return genai.Client(api_key=settings.gemini_api_key, http_options=http)
