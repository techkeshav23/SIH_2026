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
    path = os.path.join(UPLOAD_DIR, name)
    img.save(path, "JPEG", quality=90)
    # In prod this returns the Cloudinary/S3 URL; locally served via /uploads.
    return f"/uploads/{name}"


def enhance(raw_bytes: bytes, product_id: str) -> str:
    """Return URL of the enhanced image.

    Priority: rembg (true bg-removal) -> Cloudinary (hosted) -> Pillow (default,
    no deps/keys). rembg gives clean e-commerce cutouts; Pillow just does
    lighting/crop so the demo always works.
    """
    if settings.use_rembg:
        try:
            return _enhance_rembg(raw_bytes, product_id)
        except Exception:
            pass  # fall through to Pillow if rembg unavailable
    if settings.use_real_ai and settings.cloudinary_url:
        return _enhance_cloudinary(raw_bytes, product_id)
    return _enhance_local(raw_bytes, product_id)


def _enhance_rembg(raw_bytes: bytes, product_id: str) -> str:
    """True background removal (U2-Net) -> composite on white -> 1080 square."""
    from rembg import remove

    cut = Image.open(io.BytesIO(remove(raw_bytes))).convert("RGBA")

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
