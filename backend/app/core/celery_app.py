"""Celery app for durable AI jobs.

With a Redis broker (USE_CELERY=true + REDIS_URL), jobs are queued and processed
by a separate worker — they survive an API restart. Without it, tasks run
**eagerly** (inline), which keeps local dev and the test suite simple while using
the exact same code path.
"""
from celery import Celery

from app.core.config import settings

_broker = settings.redis_url or "memory://"
_backend = settings.redis_url or "cache+memory://"

celery_app = Celery("kalasetu", broker=_broker, backend=_backend)
celery_app.conf.update(
    task_always_eager=not (settings.use_celery and bool(settings.redis_url)),
    task_eager_propagates=True,
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    task_track_started=True,
    task_acks_late=True,
)

# ensure task modules are registered
celery_app.autodiscover_tasks(["app"])
