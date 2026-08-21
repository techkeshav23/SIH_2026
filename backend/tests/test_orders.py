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
