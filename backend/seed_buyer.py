"""Complete the demo seed: buyer profile/address + orders in every fulfilment
state on the demo artisan's 5 products, plus reviews."""
import httpx

BASE = "https://kalasetu-api-knzuamsjoq-el.a.run.app"
c = httpx.Client(base_url=BASE, timeout=90)

def login(phone, buyer=False):
    p = "/buyer/auth" if buyer else "/auth"
    otp = c.post(f"{p}/request-otp", json={"phone": phone}).json()["dev_otp"]
    r = c.post(f"{p}/verify-otp", json={"phone": phone, "otp": otp}).json()
    return {"Authorization": f"Bearer {r['access_token']}"}

# artisan -> get the 5 listed product ids (most-recent first)
AH = login("9000090000")
prods = [p for p in c.get("/products", headers=AH).json() if p["status"] == "listed"]
prods = sorted(prods, key=lambda p: p["created_at"])  # stable order
ids = [p["id"] for p in prods][:5]
print(f"artisan has {len(ids)} listed products")

BH = login("9000090001", buyer=True)
c.patch("/buyer/me", headers=BH, json={"name": "Ananya Traders", "org_name": "Ananya Handicrafts Pvt Ltd", "type": "B2B"})
c.post("/consent", headers=BH, json={"version": "2026-08-dpdp-v1"})
addr = c.post("/orders/addresses", headers=BH, json={
    "name": "Ananya Traders", "phone": "9000090001", "line1": "24, Craft Bazaar Road",
    "line2": "Lajpat Nagar", "city": "New Delhi", "state": "Delhi", "pincode": "110024"}).json()

def place(pid, qty):
    return c.post("/orders", headers=BH, json={"product_id": pid, "quantity": qty, "address_id": addr["id"]}).json()["id"]

# one order in each fulfilment state
o1 = place(ids[0], 5)                                                  # pending
o2 = place(ids[1], 10); c.post(f"/orders/{o2}/accept", headers=AH)     # accepted
o3 = place(ids[2], 3)                                                  # -> paid
c.post(f"/orders/{o3}/accept", headers=AH); c.post(f"/orders/{o3}/pay", headers=BH)
c.post(f"/orders/{o3}/confirm-payment", headers=BH, json={"provider_payment_id": "seed3"})
o4 = place(ids[3], 2)                                                  # -> shipped
c.post(f"/orders/{o4}/accept", headers=AH); c.post(f"/orders/{o4}/pay", headers=BH)
c.post(f"/orders/{o4}/confirm-payment", headers=BH, json={"provider_payment_id": "seed4"})
c.post(f"/orders/{o4}/ship", headers=AH)

c.post(f"/products/{ids[0]}/reviews", headers=BH, json={"rating": 5, "text": "Exquisite craftsmanship, exactly as shown."})
c.post(f"/products/{ids[2]}/reviews", headers=BH, json={"rating": 4, "text": "Very soft and warm, great quality."})

orders = c.get("/orders", headers=BH).json()
print("buyer orders by state:", {o["status"]: 1 for o in orders})
incoming = c.get("/orders/incoming", headers=AH).json()
print("artisan incoming:", len(incoming), "orders")
print("SEED COMPLETE")
