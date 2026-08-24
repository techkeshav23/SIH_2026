"""Re-enhance the demo artisan's products to durable Gemini studio shots, then
RE-LIST them (the enhance job sets status back to 'ready', which un-lists)."""
import time, httpx

BASE = "https://kalasetu-api-knzuamsjoq-el.a.run.app"
c = httpx.Client(base_url=BASE, timeout=180)

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

PRICES = {"saree": 4500, "pottery": 1200, "shawl": 6800, "painting": 2200, "jewellery": 1600}

otp = c.post("/auth/request-otp", json={"phone": "9000090000"}).json()["dev_otp"]
AH = {"Authorization": f"Bearer {c.post('/auth/verify-otp', json={'phone':'9000090000','otp':otp}).json()['access_token']}"}
prods = [p for p in c.get("/products", headers=AH).json() if p["status"] != "archived"]
print(f"re-enhancing {len(prods)} products (Gemini studio) + re-listing...")

ok = 0
for p in prods:
    asset = asset_for(p.get("title_en"))
    price = PRICES.get(asset.replace(".jpg", ""), p.get("final_price") or 1500)
    with open(f"../app/assets/demo/{asset}", "rb") as f:
        c.post("/ai/enhance-image", headers=AH,
               files={"file": (asset, f, "image/jpeg")}, data={"product_id": p["id"]})
    for _ in range(60):
        pp = c.get(f"/products/{p['id']}", headers=AH).json()
        if pp.get("status") != "processing":
            break
        time.sleep(1)
    # enhance set status to 'ready' -> re-list it
    c.patch(f"/products/{p['id']}", headers=AH, json={"status": "listed", "final_price": price})
    pp = c.get(f"/products/{p['id']}", headers=AH).json()
    url = pp.get("enhanced_image_url")
    loaded = url and c.get(url).status_code == 200
    is_listed = pp["status"] == "listed"
    if loaded and is_listed:
        ok += 1
    title = (p.get("title_en") or "?")[:34]
    print(f"  {'OK ' if loaded else 'FAIL'} {title:36} {asset:14} listed={is_listed}")

feed = c.get("/buyers/feed").json()
print(f"\n{ok}/{len(prods)} studio images durable + listed | marketplace feed now: {len(feed)}")
