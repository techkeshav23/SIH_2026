FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# rembg caches its ONNX model here; bake it in so there's no cold-start download.
ENV U2NET_HOME=/app/.u2net

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-fetch the lightweight u2netp background-removal model (~4.7MB) at build time.
RUN python -c "from rembg import new_session; new_session('u2netp')"

COPY . .

EXPOSE 8080

# Cloud Run injects $PORT (default 8080). Run migrations, then start the API.
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
