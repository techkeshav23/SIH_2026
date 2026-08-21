from app.core.config import settings


def _product(client, auth, **kw):
    return client.post("/products", headers=auth, json=kw).json()


def test_ai_quota_enforced(client, auth, monkeypatch):
    """Once the daily AI quota is used up, further AI calls return 429."""
    monkeypatch.setattr(settings, "ai_daily_quota", 3)
    p = _product(client, auth, category="saree", material="cotton")

    codes = []
    for _ in range(5):  # quota is 3
        r = client.post("/ai/catalog-from-text", headers=auth,
                        json={"product_id": p["id"], "text": "cotton saree"})
        codes.append(r.status_code)

    assert codes[:3] == [200, 200, 200]
    assert 429 in codes[3:]


def test_quota_isolated_per_user(client, auth, tokens, monkeypatch):
    """One user hitting their limit must not block another user."""
    monkeypatch.setattr(settings, "ai_daily_quota", 1)
    other = {"Authorization": f"Bearer {tokens['access_token']}"}

    p1 = _product(client, auth, category="bag", material="jute")
    p2 = _product(client, other, category="bag", material="jute")

    client.post("/ai/catalog-from-text", headers=auth, json={"product_id": p1["id"], "text": "x"})
    over = client.post("/ai/catalog-from-text", headers=auth, json={"product_id": p1["id"], "text": "x"})
    assert over.status_code == 429

    # other user still has their own budget
    ok = client.post("/ai/catalog-from-text", headers=other, json={"product_id": p2["id"], "text": "x"})
    assert ok.status_code == 200
