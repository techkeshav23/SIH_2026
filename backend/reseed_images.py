"""Re-enhance the 5 demo artisan's products so their images land in the durable
GCS bucket (old images were on wiped ephemeral containers). Verifies each loads."""
import time, httpx

BASE = "https://kalasetu-api-knzuamsjoq-el.a.run.app"
c = httpx.Client(base_url=BASE, timeout=120)

# match a product to the right bundled demo photo by a keyword in its title
ASSET_BY_KEYWORD = [
    ("banarasi", "saree.jpg"), ("saree", "saree.jpg"),
    ("pottery", "pottery.jpg"), ("vase", "pottery.jpg"),
    ("pashmina", "shawl.jpg"), ("shawl", "shawl.jpg"),
    ("madhubani", "painting.jpg"), ("painting", "painting.jpg"),
    ("filigree", "jewellery.jpg"), ("earring", "jewellery.jpg"), ("tarakasi", "jewellery.jpg"),
]

def asset_for(title: str) -> str:
    t = (title or "").lower()
    for kw, asset in ASSET_BY_KEYWORD:
        if kw in t:
            return asset
    return "saree.jpg"

otp = c.post("/auth/request-otp", json={"phone": "9000090000"}).json()["dev_otp"]
AH = {"Authorization": f"Bearer {c.post('/auth/verify-otp', json={'phone':'9000090000','otp':otp}).json()['access_token']}"}
prods = [p for p in c.get("/products", headers=AH).json() if p["status"] == "listed"]
print(f"re-enhancing {len(prods)} products...")

ok = 0
for p in prods:
    asset = asset_for(p.get("title_en"))
    with open(f"../app/assets/demo/{asset}", "rb") as f:
        c.post("/ai/enhance-image", headers=AH,
               files={"file": (asset, f, "image/jpeg")}, data={"product_id": p["id"]})
    for _ in range(40):
        pp = c.get(f"/products/{p['id']}", headers=AH).json()
        if pp.get("status") != "processing":
            break
        time.sleep(1)
    url = pp.get("enhanced_image_url")
    # verify the image actually loads through the API
    loaded = url and c.get(url).status_code == 200
    if loaded:
        ok += 1
    print(f"  {'OK ' if loaded else 'FAIL'} {p.get('title_en')[:38]:40} {asset:14} {url}")

print(f"\n{ok}/{len(prods)} images durable in GCS")
