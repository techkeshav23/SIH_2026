"""Quick check that your Gemini key + model work end-to-end.

Usage:
    1. Put GEMINI_API_KEY=... and USE_REAL_AI=true in backend/.env
    2. .venv\\Scripts\\python.exe test_gemini.py
       (optionally pass an audio file: python test_gemini.py note.wav)
"""
import sys

from app.core.config import settings
from app.services import language_ai, pricing_engine


def main() -> None:
    if not settings.gemini_api_key:
        print("❌ GEMINI_API_KEY is empty — add it to backend/.env")
        return
    if not settings.use_real_ai:
        print("⚠️  USE_REAL_AI=false — set it true in .env to hit the real model")
        return

    print(f"Model: {settings.gemini_model}\n")

    # 1) text -> listing
    print("→ Text cataloging…")
    listing = language_ai.generate_listing(
        "haath se buni banarasi silk saree, golden zari border", "saree", "silk"
    )
    print("  title_hi:", listing.title_hi)
    print("  title_en:", listing.title_en)
    print("  tags    :", listing.tags)

    # 2) pricing reasoning
    print("\n→ Pricing…")
    price = pricing_engine.suggest("test", "saree", "silk", material_cost=500)
    print(f"  ₹{price.suggested_price_min:.0f} - ₹{price.suggested_price_max:.0f}")
    print("  reason:", price.reasoning)

    # 3) audio -> listing (optional)
    if len(sys.argv) > 1:
        path = sys.argv[1]
        print(f"\n→ Voice cataloging from {path}…")
        with open(path, "rb") as f:
            audio = f.read()
        mime = "audio/wav" if path.endswith(".wav") else "audio/mp3"
        v = language_ai.catalog_from_audio(audio, mime, "hi")
        print("  transcript:", v.transcript)
        print("  title_hi  :", v.title_hi)

    print("\n✅ Gemini is working.")


if __name__ == "__main__":
    main()
