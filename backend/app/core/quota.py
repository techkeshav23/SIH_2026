"""Per-user daily AI-call quota — a cost guard so one account can't rack up an
unbounded Gemini bill. In-memory counter keyed by (user, day); swap for Redis
with a daily-expiring key in prod (same `hit`/`remaining` interface).
"""
from collections import defaultdict
from datetime import date

from app.core.config import settings

_USAGE: dict[str, int] = defaultdict(int)


def _key(user_id: str) -> str:
    return f"{user_id}:{date.today().isoformat()}"


def hit(user_id: str) -> bool:
    """Count one AI call. Returns False if the daily quota is exceeded."""
    key = _key(user_id)
    if _USAGE[key] >= settings.ai_daily_quota:
        return False
    _USAGE[key] += 1
    return True


def remaining(user_id: str) -> int:
    return max(0, settings.ai_daily_quota - _USAGE[_key(user_id)])


def reset() -> None:
    """Test helper."""
    _USAGE.clear()
