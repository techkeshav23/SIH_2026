"""Generate proper craft product images (Gemini text-to-image), save them over the
mismatched demo asset files AND upload to GCS for the live demo products. Robust
against 429 rate limits and transient network errors."""
import io, time, httpx
from google import genai
from google.genai import types
from google.cloud import storage
from PIL import Image, ImageOps

BASE = "https://kalasetu-api-knzuamsjoq-el.a.run.app"
PROJECT = "project-671a005d-50f0-4290-a6b"
BUCKET = "kalasetu-media-671a005d"
ASSETS = "../app/assets/demo"

gclient = genai.Client(vertexai=True, project=PROJECT, location="global",
                       http_options=types.HttpOptions(timeout=120_000))
bucket = storage.Client(project=PROJECT).bucket(BUCKET)

# (title keyword -> asset filename, prompt)
CRAFTS = [
    ("saree", "saree.jpg",
     "A neatly folded Banarasi silk saree in rich maroon and gold with an intricate zari "
     "border and pallu, single product, centered on a clean soft cream studio background, "
     "professional e-commerce catalogue photo, even softbox lighting, sharp, no text, no people."),
    ("pottery", "pottery.jpg",
     "A single blue Jaipur pottery vase with delicate white-and-blue hand-painted floral "
     "patterns, centered on a clean soft cream studio background, professional e-commerce "
     "catalogue photo, even lighting, sharp, no text, no people."),
    ("pashmina", "shawl.jpg",
     "A neatly folded fine Kashmiri Pashmina wool shawl in soft ivory with subtle sozni "
     "embroidery along the border, centered on a clean cream studio background, professional "
     "e-commerce catalogue photo, even lighting, no text, no people."),
    ("madhubani", "painting.jpg",
     "A Madhubani Mithila folk painting on handmade paper with intricate fish, peacock and "
     "figure motifs in natural red, ochre and black, centered on a clean cream studio "
     "background, professional e-commerce catalogue photo, no text, no people."),
    ("filigree", "jewellery.jpg",
     "A pair of exquisite Odisha silver filigree tarakasi earrings with delicate lacework, "
     "centered on a clean soft cream studio background, professional jewellery catalogue "
     "photo, macro, sharp, no text, no people."),
]

def match(title):
    t = (title or "").lower()
    kw_alias = {"saree": ["banarasi", "saree"], "pottery": ["pottery", "vase"],
                "pashmina": ["pashmina", "shawl"], "madhubani": ["madhubani", "painting"],
                "filigree": ["filigree", "tarakasi", "earring"]}
    for key, asset, prompt in CRAFTS:
        if any(a in t for a in kw_alias[key]):
            return asset, prompt
    return None, None

def gen(prompt):
    for attempt in range(12):
        try:
            resp = gclient.models.generate_content(
                model="gemini-2.5-flash-image", contents=prompt,
                config=types.GenerateContentConfig(response_modalities=["TEXT", "IMAGE"]))
            for cand in (resp.candidates or []):
                for part in (cand.content.parts or []):
                    d = getattr(getattr(part, "inline_data", None), "data", None)
                    if d:
                        return d
            time.sleep(5)
        except Exception as e:  # noqa: BLE001
            s = str(e)
            wait = 40 if ("429" in s or "RESOURCE_EXHAUSTED" in s) else 12
            print(f"    retry in {wait}s ({s[:60]})")
            time.sleep(wait)
    return None

c = httpx.Client(base_url=BASE, timeout=90)
AH = None
for _ in range(5):
    try:
        otp = c.post("/auth/request-otp", json={"phone": "9000090000"}).json().get("dev_otp")
        r = c.post("/auth/verify-otp", json={"phone": "9000090000", "otp": otp}).json()
        if "access_token" in r:
            AH = {"Authorization": f"Bearer {r['access_token']}"}; break
    except Exception:
        pass
    time.sleep(2)

prods = [p for p in c.get("/products", headers=AH).json() if p["status"] != "archived"]
ok = 0
for i, p in enumerate(prods):
    asset, prompt = match(p.get("title_en"))
    if not prompt:
        print(f"  skip (no match) {p.get('title_en')}"); continue
    data = gen(prompt)
    if not data:
        print(f"  gen FAIL {p.get('title_en')}"); continue
    im = ImageOps.fit(Image.open(io.BytesIO(data)).convert("RGB"), (1080, 1080), Image.LANCZOS)
    buf = io.BytesIO(); im.save(buf, "JPEG", quality=88)
    jpg = buf.getvalue()
    # 1) overwrite the demo asset (fixes offline demo + future bundled APK)
    with open(f"{ASSETS}/{asset}", "wb") as f:
        f.write(jpg)
    # 2) upload to GCS for the live demo product
    url = p.get("enhanced_image_url") or f"/uploads/{p['id']}_enhanced.jpg"
    bucket.blob(url.replace("/uploads/", "uploads/")).upload_from_string(jpg, content_type="image/jpeg")
    c.patch(f"/products/{p['id']}", headers=AH, json={"status": "listed"})
    ok += 1
    print(f"  OK {(p.get('title_en') or '?')[:34]:36} asset={asset}")
    if i < len(prods) - 1:
        time.sleep(25)  # space out to respect the per-minute image quota

print(f"\n{ok}/{len(prods)} craft images generated (assets + GCS)")
