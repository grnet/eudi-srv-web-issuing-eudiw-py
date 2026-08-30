# ── Stage 1: builder ──────────────────────────────────────────────────────────
FROM python:3.13-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    libffi-dev \
    libssl-dev \
    python3-dev \
    ca-certificates \
    git \
    pkg-config \
    cargo \
    rustc \
    zlib1g-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .

RUN pip install --upgrade pip \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime ─────────────────────────────────────────────────────────
FROM python:3.13-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libffi8 \
    libssl3 \
    ca-certificates \
    libjpeg62-turbo \
    zlib1g \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled packages from builder
COPY --from=builder /install /usr/local

COPY . .

# Renders the config template before starting the app, since the app's own
# loader does no variable expansion. See docker/entrypoint.sh.
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN mkdir -p /etc/eudiw/pid-issuer-dev/cert/ \
             /etc/eudiw/pid-issuer-dev/privKey/

ENV FLASK_APP="app:create_app"

# The issuer listens on 5600, matching the deployed layout. compose.yaml passes
# the port and TLS material explicitly; this default keeps the image runnable on
# its own.
EXPOSE 5600

CMD ["flask", "run", "--host=0.0.0.0", "--port=5600"]