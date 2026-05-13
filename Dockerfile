FROM python:3.13-slim

# ImageMagick for wand; libheif for pillow-heif HEIC support
RUN apt-get update && apt-get install -y --no-install-recommends \
        libmagickwand-dev \
        libheif-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Install only server runtime deps (platformio is firmware-only, not needed here)
RUN uv pip install --system --no-cache \
        flask \
        pillow \
        pillow-heif \
        requests \
        wand \
        gunicorn

COPY image_server.py ./

# Create default image directory so the server starts cleanly without a volume
RUN mkdir -p images/default

# images/ holds per-device subdirectories and device_config.json files.
# .eink_rotation_state.json is written to /app at runtime; persist it via
# a bind mount or named volume if you want state to survive container restarts.
VOLUME ["/app/images"]

EXPOSE 8000

# Single worker to avoid concurrent writes to the rotation state file.
# Timeout 120 s covers worst-case image processing time.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--timeout", "120", "image_server:app"]
