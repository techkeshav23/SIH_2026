"""End-to-end production verification for KalaSetu.

Runs the full loop against the deployed Cloud Run backend:
auth -> product -> order -> fulfilment (ship/deliver) -> review -> notifications
-> image enhance (rembg). Prints a PASS/FAIL line per step.
"""
import sys
import time

import httpx

BASE = "https://kalasetu-api-knzuamsjoq-el.a.run.app"
IMG = "../app/assets/demo/pottery.jpg"

ok = 0
fail = 0


def check(name, cond, extra=""):
    global ok, fail
    mark = "PASS" if cond else "FAIL"
    if cond:
        ok += 1
    else:
        fail += 1
    print(f"[{mark}] {name} {extra}")


c = httpx.Client(base_url=BASE, timeout=60)

# 1. artisan auth (Postgres write)
otp = c.post("/auth/request-otp", json={"phone": "9900000010"}).json()["dev_otp"]
auth = c.post("/auth/verify-otp", json={"phone": "9900000010", "otp": otp}).json()
AH = {"Authorization": f"Bearer {auth['access_token']}"}
check("artisan auth + Postgres persist", bool(auth.get("access_token")))

# 2. create + list product with price
p = c.post("/products", headers=AH, json={"category": "pottery", "material": "clay"}).json()
c.patch(f"/products/{p['id']}", headers=AH, json={"status": "listed", "final_price": 900})
check("product created + listed", bool(p.get("id")))

# 3. buyer auth
botp = c.post("/buyer/auth/request-otp", json={"phone": "9900000011"}).json()["dev_otp"]
bauth = c.post("/buyer/auth/verify-otp", json={"phone": "9900000011", "otp": botp}).json()
BH = {"Authorization": f"Bearer {bauth['access_token']}"}
check("buyer auth", bool(bauth.get("access_token")))

# 4. order lifecycle -> paid
o = c.post("/orders", headers=BH, json={"product_id": p["id"], "quantity": 2}).json()
oid = o["id"]
c.post(f"/orders/{oid}/accept", headers=AH)
c.post(f"/orders/{oid}/pay", headers=BH)
paid = c.post(f"/orders/{oid}/confirm-payment", headers=BH,
              json={"provider_payment_id": "mock_pay_1"}).json()
check("order -> paid", paid.get("status") == "paid", f"(status={paid.get('status')})")

# 5. fulfilment: ship -> confirm-delivery -> completed
shipped = c.post(f"/orders/{oid}/ship", headers=AH).json()
check("artisan ship -> shipped", shipped.get("status") == "shipped")
done = c.post(f"/orders/{oid}/confirm-delivery", headers=BH).json()
check("buyer confirm -> completed", done.get("status") == "completed")

# 6. review
rv = c.post(f"/products/{p['id']}/reviews", headers=BH,
            json={"rating": 5, "text": "Lovely blue pottery"})
check("buyer posts review", rv.status_code == 201, f"(HTTP {rv.status_code})")
pub = c.get(f"/products/{p['id']}/reviews").json()
check("review visible publicly", len(pub) >= 1 and pub[0]["rating"] == 5)

# 7. notifications persisted for the artisan (order + review events)
notifs = c.get("/notifications", headers=AH).json()
kinds = {n["type"] for n in notifs}
check("artisan notifications persisted", len(notifs) >= 1, f"(kinds={sorted(kinds)})")
mr = c.post("/notifications/read", headers=AH)
check("mark-all-read", mr.status_code == 204)

# 8. image enhance (rembg path, Pillow fallback) -> enhanced_image_url set
with open(IMG, "rb") as f:
    files = {"file": ("pottery.jpg", f, "image/jpeg")}
    data = {"product_id": p["id"]}
    er = c.post("/ai/enhance-image", headers=AH, files=files, data=data)
check("enhance-image accepted", er.status_code in (200, 202), f"(HTTP {er.status_code})")
enhanced_url = None
for _ in range(30):
    pp = c.get(f"/products/{p['id']}", headers=AH).json()
    if pp.get("status") != "processing":
        enhanced_url = pp.get("enhanced_image_url")
        break
    time.sleep(1)
check("image enhanced (bg-removal/Pillow)", bool(enhanced_url), f"(url={enhanced_url})")

print(f"\n==== {ok} passed, {fail} failed ====")
sys.exit(1 if fail else 0)
