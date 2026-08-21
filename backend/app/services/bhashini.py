"""Bhashini (govt of India Indic language stack) — STT + translation provider.

Pluggable alternative to the Vertex/Gemini audio path for the language layer.
When enabled, Bhashini transcribes the artisan's regional voice note and
translates it to English; the LLM then writes the SEO listing. Aligns the
product with Digital India / Atmanirbhar Bharat for govt deployment.

Real integration (ULCA pipeline) is stubbed with a clear TODO; enabled via
USE_BHASHINI_STT + credentials. Off by default (Vertex handles audio).
"""
import logging

from app.core.config import settings

log = logging.getLogger("kalasetu.bhashini")


def enabled() -> bool:
    return settings.use_bhashini_stt and bool(settings.bhashini_api_key)


def transcribe_translate(audio_bytes: bytes, source_lang: str = "hi") -> tuple[str, str]:
    """Return (original_transcript, english_translation)."""
    if not enabled():
        raise RuntimeError("Bhashini not configured")
    return _ulca_pipeline(audio_bytes, source_lang)


def _ulca_pipeline(audio_bytes: bytes, source_lang: str) -> tuple[str, str]:
    # TODO(prod): call the Bhashini ULCA inference pipeline:
    #   1) POST config to https://meity-auth.ulcacontrib.org/ulca/apis/v0/model/getModelsPipeline
    #      with pipelineId=settings.bhashini_pipeline_id (ASR source_lang -> translation source->en)
    #   2) POST audio (base64) to the returned inference endpoint with the auth
    #      header from step 1; parse ASR output + NMT output.
    # Headers use settings.bhashini_user_id / bhashini_api_key.
    raise NotImplementedError("Wire Bhashini ULCA ASR+NMT here")
