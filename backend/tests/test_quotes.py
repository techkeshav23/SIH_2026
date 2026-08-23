"""B2B RFQ negotiation: request -> counter -> counter -> accept -> order."""
import pytest

from tests.conftest import _login


@pytest.fixture()
def buyer(client):
    otp = client.post("/buyer/auth/request-otp", json={"phone": "+919800000200"}).json()["dev_otp"]
    r = client.post("/buyer/auth/verify-otp", json={"phone": "+919800000200", "otp": otp}).json()
    return {"Authorization": f"Bearer {r['access_token']}"}


def _listed(client, auth, price=1000):
    p = client.post("/products", headers=auth, json={"category": "rug", "material": "wool"}).json()
    client.patch(f"/products/{p['id']}", headers=auth, json={"status": "listed", "final_price": price})
    return p


def test_full_negotiation_to_order(client, auth, buyer):
    p = _listed(client, auth, price=1000)
    bh = buyer

    # buyer requests a bulk quote below list price
    q = client.post("/quotes", headers=bh,
                    json={"product_id": p["id"], "quantity": 100, "target_price": 700,
                          "message": "Bulk order for our store"}).json()
    assert q["status"] == "open" and q["turn"] == "artisan" and q["buyer_price"] == 700

    # artisan counters higher
    q = client.post(f"/quotes/{q['id']}/counter", headers=auth, json={"price": 850}).json()
    assert q["turn"] == "buyer" and q["artisan_price"] == 850

    # buyer counters back up
    q = client.post(f"/quotes/{q['id']}/counter", headers=bh, json={"price": 800}).json()
    assert q["turn"] == "artisan" and q["buyer_price"] == 800

    # artisan accepts the buyer's 800 -> order created at 800
    q = client.post(f"/quotes/{q['id']}/accept", headers=auth).json()
    assert q["status"] == "accepted" and q["agreed_price"] == 800 and q["order_id"]

    # the order exists on the buyer side at the negotiated price, ready to pay
    orders = client.get("/orders", headers=bh).json()
    o = next(o for o in orders if o["id"] == q["order_id"])
    assert o["status"] == "accepted" and o["unit_price"] == 800 and o["total_price"] == 80000

    # artisan sees the quote in incoming
    inc = client.get("/quotes/incoming", headers=auth).json()
    assert any(x["id"] == q["id"] for x in inc)


def test_only_current_turn_can_act(client, auth, buyer):
    p = _listed(client, auth)
    bh = buyer
    q = client.post("/quotes", headers=bh,
                    json={"product_id": p["id"], "quantity": 10, "target_price": 500}).json()
    # it's the artisan's turn -> buyer cannot counter again
    r = client.post(f"/quotes/{q['id']}/counter", headers=bh, json={"price": 550})
    assert r.status_code == 409


def test_buyer_accepts_artisan_counter(client, auth, buyer):
    p = _listed(client, auth, price=1000)
    bh = buyer
    q = client.post("/quotes", headers=bh,
                    json={"product_id": p["id"], "quantity": 5, "target_price": 600}).json()
    q = client.post(f"/quotes/{q['id']}/counter", headers=auth, json={"price": 750}).json()
    q = client.post(f"/quotes/{q['id']}/accept", headers=bh).json()
    assert q["status"] == "accepted" and q["agreed_price"] == 750


def test_decline_ends_negotiation(client, auth, buyer):
    p = _listed(client, auth)
    bh = buyer
    q = client.post("/quotes", headers=bh,
                    json={"product_id": p["id"], "quantity": 20, "target_price": 400}).json()
    q = client.post(f"/quotes/{q['id']}/decline", headers=auth).json()
    assert q["status"] == "declined"
    # no further action allowed
    r = client.post(f"/quotes/{q['id']}/counter", headers=bh, json={"price": 450})
    assert r.status_code == 409


def test_accept_blocked_if_product_removed(client, auth, buyer):
    p = _listed(client, auth, price=1000)
    bh = buyer
    q = client.post("/quotes", headers=bh,
                    json={"product_id": p["id"], "quantity": 10, "target_price": 800}).json()
    # artisan archives the product mid-negotiation, then tries to accept
    client.delete(f"/products/{p['id']}", headers=auth)
    r = client.post(f"/quotes/{q['id']}/accept", headers=auth)
    assert r.status_code == 409  # product no longer available


def test_quote_notifies_artisan(client, auth, buyer):
    p = _listed(client, auth)
    client.post("/quotes", headers=buyer,
                json={"product_id": p["id"], "quantity": 50, "target_price": 300})
    notifs = client.get("/notifications", headers=auth).json()
    assert any(n["type"] == "quote" for n in notifs)
