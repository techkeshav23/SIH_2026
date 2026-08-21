"""F2 — Multilingual Auto-Cataloger.

Pipeline: audio -> STT (Bhashini, Whisper fallback) -> translate ->
LLM generates a structured SEO listing in English + Hindi.

Stub path returns a plausible, category-aware listing so the demo works
without any keys. Real path is marked with TODO(ai).
"""
from app.core.config import settings
from app.models.schemas import CatalogResult

LLM_SYSTEM_PROMPT = (
    "You are an expert e-commerce copywriter for Indian handmade crafts. "
    "Given an artisan's rough spoken description, produce a professional, "
    "SEO-friendly product listing. Keep authentic cultural terms (e.g. 'Banarasi', "
    "'Pattachitra'). Return STRICT JSON with keys: title_en, title_hi, "
    "description_en, description_hi, category, material, tags (array of strings)."
)


def transcribe(audio_bytes: bytes, source_lang: str = "hi") -> tuple[str, str]:
    """Return (raw_transcript, translated_english)."""
    if settings.use_real_ai and settings.bhashini_api_key:
        return _transcribe_bhashini(audio_bytes, source_lang)
    if settings.use_real_ai and settings.openai_api_key:
        return _transcribe_whisper(audio_bytes, source_lang)
    # stub
    raw = "यह हाथ से बुनी हुई सूती साड़ी है, प्राकृतिक रंगों से रंगी गई"
    return raw, "This is a hand-woven cotton saree, dyed with natural colors."


def generate_listing(description_en: str, category: str = "", material: str = "") -> CatalogResult:
    if settings.use_real_ai and (settings.gemini_api_key or settings.openai_api_key):
        return _generate_llm(description_en, category, material)
    return _generate_stub(description_en, category, material)


# ---------- stubs (functional, no keys) ----------
def _generate_stub(description_en: str, category: str, material: str) -> CatalogResult:
    cat = category or "Handloom Textile"
    mat = material or "Cotton"
    return CatalogResult(
        title_en=f"Handcrafted {mat} {cat} — Artisan Made",
        title_hi=f"हस्तनिर्मित {mat} {cat} — कारीगर द्वारा निर्मित",
        description_en=(
            f"Authentic {mat.lower()} {cat.lower()} handcrafted by skilled Indian artisans "
            f"using traditional techniques. {description_en} Naturally dyed, durable, and "
            f"perfect for those who value sustainable, handmade craftsmanship. Each piece is "
            f"unique. Ideal for gifting and everyday elegance."
        ),
        description_hi=(
            f"कुशल भारतीय कारीगरों द्वारा पारंपरिक तकनीकों से बनाई गई प्रामाणिक {mat} {cat}। "
            f"{description_en} प्राकृतिक रंगों से रंगी, टिकाऊ और हस्तनिर्मित शिल्प को महत्व देने "
            f"वालों के लिए एकदम सही। हर टुकड़ा अद्वितीय है।"
        ),
        category=cat,
        material=mat,
        tags=["handmade", "handloom", mat.lower(), "artisan", "sustainable", "made-in-india"],
    )


# ---------- real integrations (TODO) ----------
def _transcribe_bhashini(audio_bytes: bytes, source_lang: str) -> tuple[str, str]:
    # TODO(ai): call Bhashini ULCA ASR + NMT pipeline
    #   POST https://dhruva-api.bhashini.gov.in/services/inference/pipeline
    #   headers: {settings.bhashini_api_key}, body: ASR(source_lang) -> translation(source->en)
    raise NotImplementedError("Wire Bhashini ASR+NMT here")


def _transcribe_whisper(audio_bytes: bytes, source_lang: str) -> tuple[str, str]:
    # TODO(ai): openai.audio.transcriptions.create(model="whisper-1", file=audio)
    #   then translate to English (whisper translate or a second call)
    raise NotImplementedError("Wire Whisper here")


def _generate_llm(description_en: str, category: str, material: str) -> CatalogResult:
    # TODO(ai): call Gemini/Claude with LLM_SYSTEM_PROMPT, parse strict JSON -> CatalogResult
    raise NotImplementedError("Wire LLM here")
