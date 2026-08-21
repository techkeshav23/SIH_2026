from tests.conftest import png_bytes


def _product(client, auth, **kw):
    return client.post("/products", headers=auth, json=kw).json()


def test_catalog_from_text(client, auth):
    p = _product(client, auth, category="saree", material="silk")
    r = client.post("/ai/catalog-from-text", headers=auth,
                    json={"product_id": p["id"], "text": "banarasi silk saree", "source_lang": "en"})
    assert r.status_code == 200
    body = r.json()
    assert body["title_en"] and body["title_hi"]
    assert body["status"] == "ready"


def test_enhance_image_valid(client, auth):
    p = _product(client, auth, category="pottery", material="clay")
    files = {"file": ("photo.png", png_bytes(), "image/png")}
    r = client.post("/ai/enhance-image", headers=auth,
                    data={"product_id": p["id"]}, files=files)
    assert r.status_code == 202
    # background task runs within the TestClient request cycle
    got = client.get(f"/products/{p['id']}", headers=auth).json()
    assert got["status"] == "ready"
    assert got["enhanced_image_url"]


def test_enhance_image_rejects_non_image(client, auth):
    p = _product(client, auth)
    files = {"file": ("fake.png", b"this is not an image", "image/png")}
    r = client.post("/ai/enhance-image", headers=auth,
                    data={"product_id": p["id"]}, files=files)
    assert r.status_code == 422  # content sniff fails


def test_enhance_image_rejects_unsupported_type(client, auth):
    p = _product(client, auth)
    files = {"file": ("doc.txt", b"hello", "text/plain")}
    r = client.post("/ai/enhance-image", headers=auth,
                    data={"product_id": p["id"]}, files=files)
    assert r.status_code == 415


def test_catalog_from_voice_stub(client, auth):
    p = _product(client, auth, category="shawl", material="wool")
    files = {"file": ("note.wav", b"RIFFxxxxWAVE-fake-but-nonempty", "audio/wav")}
    r = client.post("/ai/catalog-from-voice", headers=auth,
                    data={"product_id": p["id"], "source_lang": "hi"}, files=files)
    assert r.status_code == 202
    got = client.get(f"/products/{p['id']}", headers=auth).json()
    assert got["status"] == "ready"
    assert got["title_hi"]


def test_ai_requires_auth(client):
    r = client.post("/ai/catalog-from-text", json={"product_id": "x", "text": "y"})
    assert r.status_code == 401
