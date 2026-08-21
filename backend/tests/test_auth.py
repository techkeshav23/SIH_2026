from tests.conftest import _login


def test_health(client):
    assert client.get("/health").json()["status"] == "ok"
    assert client.get("/livez").status_code == 200
    assert client.get("/readyz").status_code == 200


def test_otp_login_flow(client):
    r = client.post("/auth/request-otp", json={"phone": "+919111111111"})
    assert r.status_code == 200
    otp = r.json()["dev_otp"]
    assert otp and len(otp) == 6

    r = client.post("/auth/verify-otp", json={"phone": "+919111111111", "otp": otp})
    assert r.status_code == 200
    body = r.json()
    assert body["access_token"] and body["refresh_token"]
    assert body["user"]["phone"] == "+919111111111"


def test_invalid_otp_rejected(client):
    client.post("/auth/request-otp", json={"phone": "+919222222222"})
    r = client.post("/auth/verify-otp", json={"phone": "+919222222222", "otp": "000000"})
    assert r.status_code == 401
    assert r.json()["error"]["code"] == 401  # error envelope


def test_otp_is_random_not_hardcoded(client):
    a = client.post("/auth/request-otp", json={"phone": "+919333333330"}).json()["dev_otp"]
    # a second phone gets its own OTP; hardcoded "123456" must be gone
    b = client.post("/auth/request-otp", json={"phone": "+919333333339"}).json()["dev_otp"]
    assert not (a == "123456" and b == "123456")


def test_refresh_token(client):
    r = _login(client, "+919444444444")
    resp = client.post("/auth/refresh", json={"refresh_token": r["refresh_token"]})
    assert resp.status_code == 200
    assert resp.json()["access_token"]


def test_refresh_rejects_access_token(client):
    """An access token must not be usable as a refresh token."""
    r = _login(client, "+919555555555")
    resp = client.post("/auth/refresh", json={"refresh_token": r["access_token"]})
    assert resp.status_code == 401


def test_me_requires_auth(client, auth):
    assert client.get("/me").status_code == 401
    r = client.get("/me", headers=auth)
    assert r.status_code == 200
    assert r.json()["phone"] == "+919000000001"


def test_update_profile(client, auth):
    r = client.patch("/me", headers=auth, json={"name": "Kamla Devi", "craft_type": "weaving"})
    assert r.json()["name"] == "Kamla Devi"
    assert r.json()["craft_type"] == "weaving"
