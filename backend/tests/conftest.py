import io
import os

# Configure a throwaway test environment BEFORE importing the app (settings
# read env at import time).
_TEST_DB = os.path.join(os.path.dirname(__file__), "_test.db")
if os.path.exists(_TEST_DB):
    os.remove(_TEST_DB)
os.environ["DATABASE_URL"] = f"sqlite:///{_TEST_DB}"
os.environ["RATE_LIMIT_ENABLED"] = "false"
os.environ["APP_ENV"] = "dev"
os.environ["USE_REAL_AI"] = "false"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from PIL import Image  # noqa: E402

from app.core import limiter, otp, quota  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture(autouse=True)
def _reset_state():
    otp.clear()
    limiter.reset()
    quota.reset()
    yield


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c


def _login(client, phone: str) -> dict:
    dev_otp = client.post("/auth/request-otp", json={"phone": phone}).json()["dev_otp"]
    r = client.post("/auth/verify-otp", json={"phone": phone, "otp": dev_otp}).json()
    return r


@pytest.fixture()
def auth(client) -> dict:
    r = _login(client, "+919000000001")
    return {"Authorization": f"Bearer {r['access_token']}"}


@pytest.fixture()
def tokens(client) -> dict:
    return _login(client, "+919000000002")


def png_bytes(color=(200, 120, 60)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (64, 64), color).save(buf, "PNG")
    return buf.getvalue()
