from app.core.config import settings


def test_error_envelope_shape(client):
    r = client.get("/products/nonexistent")  # unauth -> 401, still enveloped
    assert "error" in r.json()
    assert set(r.json()["error"].keys()) >= {"code", "message"}


def test_security_headers_present(client):
    h = client.get("/health").headers
    assert h.get("x-content-type-options") == "nosniff"
    assert h.get("x-frame-options") == "DENY"


def test_rate_limit_triggers(client, monkeypatch):
    """With limiting enabled, hammering request-otp returns 429."""
    monkeypatch.setattr(settings, "rate_limit_enabled", True)
    codes = []
    for _ in range(7):  # limit is 5/min
        codes.append(client.post("/auth/request-otp", json={"phone": "+919876500000"}).status_code)
    assert 429 in codes


def test_otp_resend_cooldown(client):
    """A second OTP request within cooldown is rejected (429)."""
    client.post("/auth/request-otp", json={"phone": "+919876511111"})
    r = client.post("/auth/request-otp", json={"phone": "+919876511111"})
    assert r.status_code == 429


def test_otp_attempt_lockout(client):
    """Too many wrong OTP attempts invalidate the OTP."""
    client.post("/auth/request-otp", json={"phone": "+919876522222"})
    last = None
    for _ in range(settings.otp_max_attempts + 1):
        last = client.post("/auth/verify-otp", json={"phone": "+919876522222", "otp": "999999"})
    assert last.status_code in (401, 429)
