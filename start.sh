#!/usr/bin/env bash

# Railway provides PORT env variable - map it to UVICORN_PORT
if [ -n "${PORT}" ]; then
    export UVICORN_PORT="${PORT}"
fi

ROLE="${ROLE:-all-in-one}"

if [ "${ROLE}" = "node" ]; then
    exec python node_worker.py
elif [ "${ROLE}" = "scheduler" ]; then
    exec python scheduler_worker.py
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting ${ROLE}..."
    python -m alembic upgrade head
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Database migrations failed"
        exit 1
    fi

    exec python main.py
fi