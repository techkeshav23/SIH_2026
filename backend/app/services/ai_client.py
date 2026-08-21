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


def build_client():
    """Construct a genai.Client for Vertex AI (or the Developer API fallback)."""
    from google import genai
    from google.genai import types

    http = types.HttpOptions(timeout=TIMEOUT_MS)
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
