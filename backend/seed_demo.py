"""Seed a rich, REAL demo account on prod: artisan with AI-generated listings,
enhanced photos, prices, and a buyer with orders in every fulfilment state.

Login (SMS-free, OTP auto-fills):
  Artisan : 9000090000
  Buyer   : 9000090001
"""
import time, httpx

BASE = "https://kalasetu-api-knzuamsjoq-el.a.run.app"
ART = "9000090000"
BUY = "9000090001"
c = httpx.Client(base_url=BASE, timeout=120)

def login(phone, buyer=False):
    p = "/buyer/auth" if buyer else "/auth"
    otp = c.post(f"{p}/request-otp", json={"phone": phone}).json()["dev_otp"]
    r = c.post(f"{p}/verify-otp", json={"phone": phone, "otp": otp}).json()
    return {"Authorization": f"Bearer {r['access_token']}"}, r

print("== artisan login + profile ==")
AH, auth = login(ART)
uid = auth["user"]["id"]
c.patch("/me", headers=AH, json={"name": "कमला देवी", "craft_type": "Handloom Weaving", "region": "Varanasi, UP"})
c.post("/consent", headers=AH, json={"version": "2026-08-dpdp-v1"})

PRODUCTS = [
    ("textile", "silk",  "saree.jpg",     "handwoven Banarasi silk saree with golden zari work", 4500),
    ("pottery", "clay",  "pottery.jpg",   "blue pottery decorative vase, hand painted in Jaipur style", 1200),
    ("textile", "wool",  "shawl.jpg",     "handwoven Pashmina wool shawl from Kashmir, soft and warm", 6800),
    ("art",     "paper", "painting.jpg",  "Madhubani folk painting on handmade paper, natural colours", 2200),
    ("jewellery","silver","jewellery.jpg","silver filigree earrings, traditional Odisha tarakasi work", 1600),
]

listed_ids = []
for cat, mat, img, text, price in PRODUCTS:
    p = c.post("/products", headers=AH, json={"category": cat, "material": mat}).json()
    pid = p["id"]
    # real AI listing
    c.post("/ai/catalog-from-text", headers=AH,
           json={"product_id": pid, "text": text, "source_lang": "en"})
    # real AI price
    c.post("/pricing/suggest", headers=AH, json={"product_id": pid})
    # real image enhance (rembg)
    with open(f"../app/assets/demo/{img}", "rb") as f:
        c.post("/ai/enhance-image", headers=AH,
               files={"file": (img, f, "image/jpeg")}, data={"product_id": pid})
    for _ in range(40):
        if c.get(f"/products/{pid}", headers=AH).json().get("status") != "processing":
            break
        time.sleep(1)
    # publish with a final price
    c.patch(f"/products/{pid}", headers=AH, json={"status": "listed", "final_price": price})
    listed_ids.append(pid)
    print(f"  listed: {c.get(f'/products/{pid}', headers=AH).json().get('title_en')}  (Rs {price})")

print("\n== buyer login + address ==")
BH, _ = login(BUY, buyer=True)
c.patch("/buyer/me", headers=BH, json={"name": "Ananya Traders", "org_name": "Ananya Handicrafts Pvt Ltd", "type": "B2B"})
c.post("/consent", headers=BH, json={"version": "2026-08-dpdp-v1"})
addr = c.post("/orders/addresses", headers=BH, json={
    "name": "Ananya Traders", "phone": "9000090001", "line1": "24, Craft Bazaar Road",
    "line2": "Lajpat Nagar", "city": "New Delhi", "state": "Delhi", "pincode": "110024"}).json()

def place(pid, qty):
    return c.post("/orders", headers=BH, json={"product_id": pid, "quantity": qty, "address_id": addr["id"]}).json()["id"]

print("\n== orders in every fulfilment state (for a live demo) ==")
# 1) pending  -> artisan can Accept/Reject live
o1 = place(listed_ids[0], 5)
# 2) accepted -> buyer can Pay live
o2 = place(listed_ids[1], 10); c.post(f"/orders/{o2}/accept", headers=AH)
# 3) paid     -> artisan can Mark shipped live
o3 = place(listed_ids[2], 3)
c.post(f"/orders/{o3}/accept", headers=AH); c.post(f"/orders/{o3}/pay", headers=BH)
c.post(f"/orders/{o3}/confirm-payment", headers=BH, json={"provider_payment_id": "seed_pay_3"})
# 4) shipped  -> buyer can Confirm received live
o4 = place(listed_ids[3], 2)
c.post(f"/orders/{o4}/accept", headers=AH); c.post(f"/orders/{o4}/pay", headers=BH)
c.post(f"/orders/{o4}/confirm-payment", headers=BH, json={"provider_payment_id": "seed_pay_4"})
c.post(f"/orders/{o4}/ship", headers=AH)
print("  pending, accepted, paid, shipped — one of each")

# reviews (real)
c.post(f"/products/{listed_ids[0]}/reviews", headers=BH, json={"rating": 5, "text": "Exquisite craftsmanship, exactly as shown."})
c.post(f"/products/{listed_ids[2]}/reviews", headers=BH, json={"rating": 4, "text": "Very soft and warm, good quality."})

print("\n==== SEED DONE ====")
print(f"  Artisan login: {ART}   ({len(listed_ids)} products, 4 incoming orders, 2 reviews)")
print(f"  Buyer   login: {BUY}   (4 orders across states, 1 address)")
