ARG PYTHON_VERSION=3.14

# Build the dashboard here so the runtime image never needs bun. The output
# lands in /dashboard/build, which is where dashboard/__init__.py expects it.
FROM oven/bun:1 AS dashboard-builder
ARG VITE_BASE_API=/
WORKDIR /dashboard
COPY dashboard/package.json dashboard/bun.lock ./
RUN bun install --frozen-lockfile
COPY dashboard/ ./
RUN VITE_BASE_API="$VITE_BASE_API" bun run build --outDir build --assetsDir statics \
    && cp build/index.html build/404.html


FROM ghcr.io/astral-sh/uv:python$PYTHON_VERSION-bookworm-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

ENV UV_PYTHON_DOWNLOADS=0

WORKDIR /build
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,id=s/6a913be4-c045-453d-8888-c43b24c31dfd-/root/.cache/uv,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev
ADD . /build
# Only the Python integration module is needed at runtime; the compiled assets
# are copied in from the dashboard-builder stage.
RUN find /build/dashboard -mindepth 1 -maxdepth 1 ! -name __init__.py -exec rm -rf {} +
COPY --from=dashboard-builder /dashboard/build /build/dashboard/build
RUN --mount=type=cache,id=s/6a913be4-c045-453d-8888-c43b24c31dfd-/root/.cache/uv,target=/root/.cache/uv \
    uv sync --frozen --no-dev


FROM python:$PYTHON_VERSION-slim-bookworm

COPY --from=builder /build /code
WORKDIR /code

ENV PATH="/code/.venv/bin:$PATH"

# Keep the runtime trust store explicit. Outbound notification clients use it
# without replacing Python's process-wide SSLContext.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY cli_wrapper.sh /usr/bin/pasarguard-cli
RUN chmod +x /usr/bin/pasarguard-cli

COPY tui_wrapper.sh /usr/bin/pasarguard-tui
RUN chmod +x /usr/bin/pasarguard-tui

# Copy healthcheck script
COPY healthcheck.sh /code/healthcheck.sh
RUN chmod +x /code/healthcheck.sh

RUN chmod +x /code/start.sh

ENTRYPOINT ["/code/start.sh"]
