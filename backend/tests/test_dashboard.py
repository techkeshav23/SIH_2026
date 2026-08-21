import pytest

from tests.conftest import _login


@pytest.fixture()
def buyer(client):
    dev = client.post("/buyer/auth/request-otp", json={"phone": "+919700000001"}).json()["dev_otp"]
    r = client.post("/buyer/auth/verify-otp", json={"phone": "+919700000001", "otp": dev}).json()
    return {"Authorization": f"Bearer {r['access_token']}"}


def test_artisan_dashboard(client, buyer):
    # a fresh artisan so counts are deterministic (test DB is shared across tests)
    tok = _login(client, "+919700009999")
    auth = {"Authorization": f"Bearer {tok['access_token']}"}

    # two products, one listed & sold
    p1 = client.post("/products", headers=auth, json={"category": "saree", "material": "silk"}).json()
    client.post("/products", headers=auth, json={"category": "bag", "material": "jute"}).json()
    client.patch(f"/products/{p1['id']}", headers=auth, json={"status": "listed", "final_price": 2000})

    # buyer orders -> artisan accepts -> buyer pays
    o = client.post("/orders", headers=buyer, json={"product_id": p1["id"], "quantity": 2}).json()
    client.post(f"/orders/{o['id']}/accept", headers=auth)
    client.post(f"/orders/{o['id']}/pay", headers=buyer)
    client.post(f"/orders/{o['id']}/confirm-payment", headers=buyer, json={"provider_payment_id": "m"})

    stats = client.get("/dashboard/artisan", headers=auth).json()
    assert stats["products"] == 2
    assert stats["listed"] == 1
    assert stats["orders_total"] == 1
    assert stats["orders_paid"] == 1
    assert stats["earnings"] == 4000  # 2000 * 2


def test_dashboard_requires_auth(client):
    assert client.get("/dashboard/artisan").status_code == 401
