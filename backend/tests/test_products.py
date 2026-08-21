def _create(client, auth, **kw):
    return client.post("/products", headers=auth, json=kw).json()


def test_create_and_list(client, auth):
    p = _create(client, auth, category="saree", material="cotton")
    assert p["status"] == "draft"
    assert p["category"] == "saree"

    items = client.get("/products", headers=auth).json()
    assert any(i["id"] == p["id"] for i in items)


def test_get_and_update(client, auth):
    p = _create(client, auth, category="pottery", material="clay")
    r = client.patch(f"/products/{p['id']}", headers=auth,
                     json={"final_price": 450, "status": "listed"})
    assert r.json()["final_price"] == 450
    assert r.json()["status"] == "listed"


def test_ownership_isolation(client, auth, tokens):
    """A user must not see or fetch another user's product."""
    p = _create(client, auth, category="rug", material="wool")
    other = {"Authorization": f"Bearer {tokens['access_token']}"}
    assert client.get(f"/products/{p['id']}", headers=other).status_code == 404
    other_list = client.get("/products", headers=other).json()
    assert all(i["id"] != p["id"] for i in other_list)


def test_status_filter(client, auth):
    a = _create(client, auth, category="bag", material="jute")
    client.patch(f"/products/{a['id']}", headers=auth, json={"status": "listed"})
    listed = client.get("/products?status_filter=listed", headers=auth).json()
    assert all(i["status"] == "listed" for i in listed)
