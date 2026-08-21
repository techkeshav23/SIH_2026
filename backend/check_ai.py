"""Quick check that your AI backend (Vertex AI or Gemini API) works end-to-end.

Usage:
    1. Configure backend/.env:
         USE_REAL_AI=true
         USE_VERTEX=true
         GCP_PROJECT=your-project
         GCP_LOCATION=asia-south1
       and auth:  gcloud auth application-default login
                  (or GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json)
    2. .venv\\Scripts\\python.exe check_ai.py
       (optionally pass an audio file: python check_ai.py note.wav)
"""
import sys

from app.core.config import settings
from app.services import ai_client, language_ai, pricing_engine


def main() -> None:
    if not ai_client.ai_enabled():
        print("⚠️  AI not enabled. Set USE_REAL_AI=true and either")
        print("    USE_VERTEX=true + GCP_PROJECT, or USE_VERTEX=false + GEMINI_API_KEY.")
        return

    backend = f"Vertex AI (project={settings.gcp_project}, {settings.gcp_location})" \
        if settings.use_vertex else "Gemini Developer API"
    print(f"Backend: {backend}\nModel:   {settings.gemini_model}\n")

    print("→ Text cataloging…")
    listing = language_ai.generate_listing(
        "haath se buni banarasi silk saree, golden zari border", "saree", "silk"
    )
    print("  title_hi:", listing.title_hi)
    print("  title_en:", listing.title_en)
    print("  tags    :", listing.tags)

    print("\n→ Pricing…")
    price = pricing_engine.suggest("test", "saree", "silk", material_cost=500)
    print(f"  ₹{price.suggested_price_min:.0f} - ₹{price.suggested_price_max:.0f}")
    print("  reason:", price.reasoning)

    if len(sys.argv) > 1:
        path = sys.argv[1]
        print(f"\n→ Voice cataloging from {path}…")
        with open(path, "rb") as f:
            audio = f.read()
        mime = "audio/wav" if path.endswith(".wav") else "audio/mp3"
        v = language_ai.catalog_from_audio(audio, mime, "hi")
        print("  transcript:", v.transcript)
        print("  title_hi  :", v.title_hi)

    print("\n✅ AI backend is working.")


if __name__ == "__main__":
    main()
