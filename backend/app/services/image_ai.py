"""F1 — AI Image Studio.

Pipeline: raw image -> background removal -> composite on clean bg ->
lighting/contrast fix -> square e-commerce crop -> save.

Real path uses Cloudinary AI (or rembg). Stub path does a *real* Pillow
enhancement (autocontrast + white canvas + square crop) so the demo works
with zero external keys.
"""
import io
import os

from PIL import Image, ImageEnhance, ImageOps

from app.core.config import settings

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)


def _save(img: Image.Image, name: str) -> str:
    # Durable storage (GCS) when configured; else local disk (dev/demo).
    if settings.gcs_bucket:
        from app.core import gcs

        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=90)
        gcs.put_image(name, buf.getvalue())
        return f"/uploads/{name}"
    path = os.path.join(UPLOAD_DIR, name)
    img.save(path, "JPEG", quality=90)
    return f"/uploads/{name}"


_STUDIO_PROMPT = (
    "Re-photograph THIS EXACT handmade product as a professional e-commerce product "
    "shot. Keep the product identical in shape, colour, pattern and every detail — do "
    "NOT invent, add or alter the product. Place it on a clean, softly-lit neutral "
    "studio background (subtle warm cream), remove any background clutter, and improve "
    "lighting, sharpness and colour accuracy. Centered, square framing. No text, no "
    "watermark, no extra props."
)


def enhance(raw_bytes: bytes, product_id: str) -> str:
    """Return URL of the enhanced image.

    Priority: Gemini image-to-image studio shot (keeps the real product, best
    quality) -> rembg cutout -> Cloudinary -> Pillow. Each degrades gracefully so
    the app always produces something.
    """
    if settings.use_gemini_image:
        try:
            return _enhance_gemini(raw_bytes, product_id)
        except Exception as e:  # noqa: BLE001
            import logging
            logging.getLogger("kalasetu.ai").warning("Gemini image enhance failed: %s", e)
    if settings.use_rembg:
        try:
            return _enhance_rembg(raw_bytes, product_id)
        except Exception:
            pass  # fall through to Pillow if rembg unavailable
    if settings.use_real_ai and settings.cloudinary_url:
        return _enhance_cloudinary(raw_bytes, product_id)
    return _enhance_local(raw_bytes, product_id)


def _enhance_gemini(raw_bytes: bytes, product_id: str) -> str:
    """Gemini 2.5 Flash Image: the artisan's photo -> a clean studio product shot.
    Retries a couple of times (the model occasionally returns text only)."""
    from google import genai
    from google.genai import types

    client = genai.Client(
        vertexai=True, project=settings.gcp_project,
        location=settings.gemini_image_location,
        http_options=types.HttpOptions(timeout=90_000),
    )
    part = types.Part.from_bytes(data=raw_bytes, mime_type="image/jpeg")
    data = None
    for _ in range(3):
        resp = client.models.generate_content(
            model=settings.gemini_image_model,
            contents=[_STUDIO_PROMPT, part],
            config=types.GenerateContentConfig(response_modalities=["TEXT", "IMAGE"]),
        )
        for cand in (resp.candidates or []):
            for p in (cand.content.parts or []):
                d = getattr(getattr(p, "inline_data", None), "data", None)
                if d:
                    data = d
                    break
            if data:
                break
        if data:
            break
    if not data:
        raise RuntimeError("no image returned after retries")

    out = Image.open(io.BytesIO(data)).convert("RGB")
    out = ImageOps.fit(out, (1080, 1080), Image.LANCZOS)  # clean 1:1 e-commerce crop
    return _save(out, f"{product_id}_enhanced.jpg")


_rembg_session = None


def warmup() -> None:
    """Pre-build the rembg session AND run one tiny inference at startup, so the
    first real /ai/enhance-image isn't slow (onnxruntime optimizes lazily on the
    first run — ~60-90s otherwise, even on a warm min-instance container)."""
    if not settings.use_rembg:
        return
    try:
        import io as _io

        from rembg import remove

        buf = _io.BytesIO()
        Image.new("RGB", (32, 32), (200, 180, 160)).save(buf, "PNG")
        remove(buf.getvalue(), session=_get_rembg_session())
        import logging
        logging.getLogger("kalasetu.ai").info("rembg warmed up")
    except Exception as e:  # noqa: BLE001
        import logging
        logging.getLogger("kalasetu.ai").warning("rembg warmup failed: %s", e)


def _get_rembg_session():
    """Lazily build (and cache) a lightweight u2netp session. u2netp is ~4.7MB
    and low-memory — safe for a 1-2GB Cloud Run container."""
    global _rembg_session
    if _rembg_session is None:
        from rembg import new_session

        _rembg_session = new_session("u2netp")
    return _rembg_session


def _enhance_rembg(raw_bytes: bytes, product_id: str) -> str:
    """True background removal (U2-Net) -> composite on white -> 1080 square."""
    from rembg import remove

    cut = Image.open(io.BytesIO(remove(raw_bytes, session=_get_rembg_session()))).convert("RGBA")

    side = max(cut.size)
    canvas = Image.new("RGBA", (side, side), (255, 255, 255, 255))
    canvas.paste(cut, ((side - cut.width) // 2, (side - cut.height) // 2), cut)
    out = canvas.convert("RGB")
    out = ImageOps.autocontrast(out, cutoff=1)
    out = ImageEnhance.Sharpness(out).enhance(1.15)
    out = out.resize((1080, 1080), Image.LANCZOS)
    return _save(out, f"{product_id}_enhanced.jpg")


def _enhance_local(raw_bytes: bytes, product_id: str) -> str:
    img = Image.open(io.BytesIO(raw_bytes)).convert("RGB")

    # 1. lighting / white-balance-ish fix
    img = ImageOps.autocontrast(img, cutoff=1)
    img = ImageEnhance.Color(img).enhance(1.08)
    img = ImageEnhance.Sharpness(img).enhance(1.15)

    # 2. square crop to e-commerce 1:1, centered
    side = min(img.size)
    left = (img.width - side) // 2
    top = (img.height - side) // 2
    img = img.crop((left, top, left + side, top + side))

    # 3. paste onto clean canvas + resize to 1080
    canvas = Image.new("RGB", (side, side), (255, 255, 255))
    canvas.paste(img, (0, 0))
    canvas = canvas.resize((1080, 1080), Image.LANCZOS)

    return _save(canvas, f"{product_id}_enhanced.jpg")


def _enhance_cloudinary(raw_bytes: bytes, product_id: str) -> str:
    # TODO(ai): upload with Cloudinary and apply e_background_removal + e_improve
    #   import cloudinary, cloudinary.uploader
    #   cloudinary.config(cloudinary_url=settings.cloudinary_url)
    #   res = cloudinary.uploader.upload(raw_bytes, public_id=product_id,
    #           background_removal="cloudinary_ai",
    #           transformation=[{"effect": "improve"}, {"width": 1080, "height": 1080, "crop": "pad", "background": "white"}])
    #   return res["secure_url"]
    raise NotImplementedError("Wire Cloudinary here")
