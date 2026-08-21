"""Lightweight in-memory sliding-window rate limiter.

Zero deps, per-(client-ip, bucket) windows. Good enough for a single-process
deploy; swap the `_HITS` dict for Redis when you scale horizontally.
Disabled entirely when settings.rate_limit_enabled is False (e.g. tests).
"""
import time
from collections import defaultdict

from fastapi import HTTPException, Request, status

from app.core.config import settings

_HITS: dict[str, list[float]] = defaultdict(list)


def _client_ip(request: Request) -> str:
    fwd = request.headers.get("x-forwarded-for")
    if fwd:
        return fwd.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def rate_limit(bucket: str, max_calls: int, window_sec: int):
    """Return a FastAPI dependency enforcing max_calls per window per client."""

    def dependency(request: Request) -> None:
        if not settings.rate_limit_enabled:
            return
        key = f"{bucket}:{_client_ip(request)}"
        now = time.time()
        hits = [t for t in _HITS[key] if now - t < window_sec]
        if len(hits) >= max_calls:
            retry = int(window_sec - (now - hits[0]))
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded — retry in {retry}s",
                headers={"Retry-After": str(max(retry, 1))},
            )
        hits.append(now)
        _HITS[key] = hits

    return dependency


def reset() -> None:
    """Test helper."""
    _HITS.clear()
