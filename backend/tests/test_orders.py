"""End-to-end commerce: buyer auth -> order -> artisan accept -> pay -> confirm."""
import pytest

from tests.conftest import _login


@pytest.fixture()
def buyer(client):
    phone = "+919800000001"
    dev = client.post("/buyer/auth/request-otp", json={"phone": phone}).json()["dev_otp"]
    r = client.post("/buyer/auth/verify-otp", json={"phone": phone, "otp": dev}).json()
    return {"Authorization": f"Bearer {r['access_token']}", "id": r["buyer"]["id"]}


def _listed_product(client, auth, price=1200):
    p = client.post("/products", headers=auth, json={"category": "rug", "material": "wool"}).json()
    client.patch(f"/products/{p['id']}", headers=auth,
                 json={"status": "listed", "final_price": price})
    return p


def test_buyer_auth_flow(client, buyer):
    r = client.get("/buyer/me", headers={"Authorization": buyer["Authorization"]})
    assert r.status_code == 200
    assert r.json()["phone"] == "+919800000001"


def test_buyer_token_cannot_access_artisan_routes(client, buyer):
    # buyer token must not pass artisan auth
    r = client.get("/products", headers={"Authorization": buyer["Authorization"]})
    assert r.status_code == 401


def test_full_order_lifecycle(client, auth, buyer):
    product = _listed_product(client, auth, price=1000)
    bh = {"Authorization": buyer["Authorization"]}

    # buyer places order
    o = client.post("/orders", headers=bh,
                    json={"product_id": product["id"], "quantity": 3}).json()
    assert o["status"] == "pending"
    assert o["total_price"] == 3000
    oid = o["id"]

    # artisan sees it incoming
    incoming = client.get("/orders/incoming", headers=auth).json()
    assert any(i["id"] == oid for i in incoming)

    # artisan accepts
    acc = client.post(f"/orders/{oid}/accept", headers=auth).json()
    assert acc["status"] == "accepted"

    # buyer pays -> checkout
    pay = client.post(f"/orders/{oid}/pay", headers=bh)
    assert pay.status_code == 200
    assert pay.json()["provider_order_id"]

    # buyer confirms payment (mock verify ok) -> paid
    conf = client.post(f"/orders/{oid}/confirm-payment", headers=bh,
                       json={"provider_payment_id": "mock_pay_123"})
    assert conf.status_code == 200
    assert conf.json()["status"] == "paid"


def test_cannot_pay_before_accept(client, auth, buyer):
    product = _listed_product(client, auth)
    bh = {"Authorization": buyer["Authorization"]}
    o = client.post("/orders", headers=bh, json={"product_id": product["id"]}).json()
    r = client.post(f"/orders/{o['id']}/pay", headers=bh)
    assert r.status_code == 409  # must be accepted first


def test_artisan_cannot_accept_others_order(client, auth, buyer):
    product = _listed_product(client, auth)
    bh = {"Authorization": buyer["Authorization"]}
    o = client.post("/orders", headers=bh, json={"product_id": product["id"]}).json()

    other_artisan = _login(client, "+919000000099")
    oh = {"Authorization": f"Bearer {other_artisan['access_token']}"}
    r = client.post(f"/orders/{o['id']}/accept", headers=oh)
    assert r.status_code == 403


def test_reject_order(client, auth, buyer):
    product = _listed_product(client, auth)
    bh = {"Authorization": buyer["Authorization"]}
    o = client.post("/orders", headers=bh, json={"product_id": product["id"]}).json()
    r = client.post(f"/orders/{o['id']}/reject", headers=auth).json()
    assert r["status"] == "rejected"


def test_cannot_order_unlisted_product(client, auth, buyer):
    p = client.post("/products", headers=auth, json={"category": "bag"}).json()  # draft
    bh = {"Authorization": buyer["Authorization"]}
    r = client.post("/orders", headers=bh, json={"product_id": p["id"]})
    assert r.status_code == 404


def test_order_requires_buyer_auth(client, auth):
    product = _listed_product(client, auth)
    # artisan token is not a buyer token
    r = client.post("/orders", headers=auth, json={"product_id": product["id"]})
    assert r.status_code == 401


def _paid_order(client, auth, buyer):
    """Drive an order all the way to 'paid' and return (order_id, buyer_headers)."""
    product = _listed_product(client, auth, price=1000)
    bh = {"Authorization": buyer["Authorization"]}
    oid = client.post("/orders", headers=bh, json={"product_id": product["id"]}).json()["id"]
    client.post(f"/orders/{oid}/accept", headers=auth)
    client.post(f"/orders/{oid}/pay", headers=bh)
    client.post(f"/orders/{oid}/confirm-payment", headers=bh,
                json={"provider_payment_id": "mock_pay_123"})
    return oid, bh


def test_fulfilment_ship_then_deliver(client, auth, buyer):
    oid, bh = _paid_order(client, auth, buyer)

    # artisan ships
    shipped = client.post(f"/orders/{oid}/ship", headers=auth)
    assert shipped.status_code == 200 and shipped.json()["status"] == "shipped"

    # buyer confirms receipt -> completed
    done = client.post(f"/orders/{oid}/confirm-delivery", headers=bh)
    assert done.status_code == 200 and done.json()["status"] == "completed"


def test_cannot_ship_before_paid(client, auth, buyer):
    product = _listed_product(client, auth)
    bh = {"Authorization": buyer["Authorization"]}
    oid = client.post("/orders", headers=bh, json={"product_id": product["id"]}).json()["id"]
    r = client.post(f"/orders/{oid}/ship", headers=auth)
    assert r.status_code == 409  # not paid yet


def test_only_owner_artisan_can_ship(client, auth, buyer):
    oid, _ = _paid_order(client, auth, buyer)
    other = _login(client, "+919000000098")
    r = client.post(f"/orders/{oid}/ship",
                    headers={"Authorization": f"Bearer {other['access_token']}"})
    assert r.status_code == 403


def test_buyer_cancels_unpaid_order(client, auth, buyer):
    product = _listed_product(client, auth)
    bh = {"Authorization": buyer["Authorization"]}
    oid = client.post("/orders", headers=bh, json={"product_id": product["id"]}).json()["id"]
    r = client.post(f"/orders/{oid}/cancel", headers=bh)
    assert r.status_code == 200 and r.json()["status"] == "cancelled"


def test_cannot_cancel_paid_order(client, auth, buyer):
    oid, bh = _paid_order(client, auth, buyer)
    r = client.post(f"/orders/{oid}/cancel", headers=bh)
    assert r.status_code == 409


def test_dpdp_consent_recorded(client, auth, buyer):
    # artisan consent persists on /me
    assert client.post("/consent", headers=auth, json={"version": "2026-08-dpdp-v1"}).status_code == 204
    me = client.get("/me", headers=auth).json()
    assert me["consent_version"] == "2026-08-dpdp-v1"

    # buyer consent persists on /buyer/me
    bh = {"Authorization": buyer["Authorization"]}
    assert client.post("/consent", headers=bh, json={"version": "2026-08-dpdp-v1"}).status_code == 204
    bme = client.get("/buyer/me", headers=bh).json()
    assert bme["consent_version"] == "2026-08-dpdp-v1"


def test_consent_requires_auth(client):
    assert client.post("/consent", json={"version": "x"}).status_code == 401


def _address_payload(**over):
    base = {
        "name": "Radha Sharma", "phone": "9876500011", "line1": "12 MG Road",
        "line2": "Near mall", "city": "Jaipur", "state": "Rajasthan", "pincode": "302001",
    }
    base.update(over)
    return base


def test_address_crud_and_order_snapshot(client, auth, buyer):
    bh = {"Authorization": buyer["Authorization"]}
    product = _listed_product(client, auth, price=500)

    # first address becomes default automatically
    a = client.post("/orders/addresses", headers=bh, json=_address_payload()).json()
    assert a["is_default"] is True
    assert any(x["id"] == a["id"] for x in client.get("/orders/addresses", headers=bh).json())

    # order carries a denormalized shipping snapshot
    o = client.post("/orders", headers=bh,
                    json={"product_id": product["id"], "quantity": 1, "address_id": a["id"]}).json()
    assert o["ship_name"] == "Radha Sharma"
    assert "Jaipur" in o["ship_address"]

    # delete
    assert client.delete(f"/orders/addresses/{a['id']}", headers=bh).status_code == 204


def test_order_rejects_foreign_address(client, auth, buyer):
    product = _listed_product(client, auth, price=500)
    # a second buyer owns the address
    otp = client.post("/buyer/auth/request-otp", json={"phone": "+919800000077"}).json()["dev_otp"]
    other = client.post("/buyer/auth/verify-otp", json={"phone": "+919800000077", "otp": otp}).json()
    oh = {"Authorization": f"Bearer {other['access_token']}"}
    addr = client.post("/orders/addresses", headers=oh, json=_address_payload()).json()

    bh = {"Authorization": buyer["Authorization"]}
    r = client.post("/orders", headers=bh,
                    json={"product_id": product["id"], "address_id": addr["id"]})
    assert r.status_code == 404  # not the buyer's address


def test_storefront_public(client, auth):
    me = client.get("/me", headers=auth).json()
    client.patch("/me", headers=auth, json={"name": "Kamla Devi", "craft_type": "Weaving"})
    _listed_product(client, auth, price=999)

    shop = client.get(f"/buyers/storefront/{me['id']}")
    assert shop.status_code == 200
    body = shop.json()
    assert body["name"] == "Kamla Devi"
    assert len(body["products"]) >= 1


def test_reviews_and_notifications(client, auth, buyer):
    """Buyer reviews a product; artisan gets a persisted notification."""
    product = _listed_product(client, auth)
    bh = {"Authorization": buyer["Authorization"]}

    # public read starts empty
    assert client.get(f"/products/{product['id']}/reviews").json() == []

    # buyer posts a review
    r = client.post(f"/products/{product['id']}/reviews", headers=bh,
                    json={"rating": 5, "text": "Beautiful craftsmanship"})
    assert r.status_code == 201 and r.json()["rating"] == 5

    # visible publicly now
    reviews = client.get(f"/products/{product['id']}/reviews").json()
    assert len(reviews) == 1 and reviews[0]["text"] == "Beautiful craftsmanship"

    # artisan has a persisted 'review' notification
    notifs = client.get("/notifications", headers=auth).json()
    assert any(n["type"] == "review" for n in notifs)

    # mark all read
    assert client.post("/notifications/read", headers=auth).status_code == 204
    after = client.get("/notifications", headers=auth).json()
    assert all(n["read"] for n in after)
