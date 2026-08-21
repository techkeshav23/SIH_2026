def _product(client, auth, **kw):
    return client.post("/products", headers=auth, json=kw).json()


def test_pricing_suggestion(client, auth):
    p = _product(client, auth, category="saree", material="silk")
    r = client.post("/pricing/suggest", headers=auth,
                    json={"product_id": p["id"], "material_cost": 500})
    assert r.status_code == 200
    body = r.json()
    assert body["suggested_price_min"] > 0
    assert body["suggested_price_max"] >= body["suggested_price_min"]
    assert body["reasoning"]
    assert len(body["comparables"]) >= 1


def test_pricing_respects_material_cost_floor(client, auth):
    """Price should never fall below a fair margin over material cost."""
    p = _product(client, auth, category="unknowncat", material="unknownmat")
    r = client.post("/pricing/suggest", headers=auth,
                    json={"product_id": p["id"], "material_cost": 5000}).json()
    assert r["suggested_price_max"] >= 5000  # 2.2x floor pushes it well above cost


def test_buyer_feed_and_inquiry(client, auth):
    p = _product(client, auth, category="rug", material="wool")
    client.post("/ai/catalog-from-text", headers=auth,
                json={"product_id": p["id"], "text": "handmade wool rug"})
    client.patch(f"/products/{p['id']}", headers=auth,
                 json={"status": "listed", "final_price": 3200})

    feed = client.get("/buyers/feed").json()
    assert any(i["id"] == p["id"] for i in feed)

    r = client.post("/buyers/inquiries",
                    json={"product_id": p["id"], "org_name": "Fabindia", "message": "MOQ?"})
    assert r.status_code == 201
    assert r.json()["status"] == "new"


def test_buyer_feed_only_listed(client, auth):
    """Draft products must not appear in the public buyer feed."""
    p = _product(client, auth, category="bag", material="jute")  # stays draft
    feed = client.get("/buyers/feed").json()
    assert all(i["id"] != p["id"] for i in feed)
