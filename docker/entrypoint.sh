#!/bin/sh
set -e

echo "[ENTRYPOINT] Starting..."
echo "[ENTRYPOINT] DB_HOST=${DB_HOST}"
echo "[ENTRYPOINT] DB_PORT=${DB_PORT}"
echo "[ENTRYPOINT] DB_NAME=${DB_NAME}"
echo "[ENTRYPOINT] DB_USER=${DB_USER}"

# Attendre PostgreSQL avec pg_isready
echo "[ENTRYPOINT] Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."

MAX_TRIES=30
COUNT=0

until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" 2>/dev/null; do
    COUNT=$((COUNT + 1))
    if [ $COUNT -ge $MAX_TRIES ]; then
        echo "[ENTRYPOINT] ERROR: PostgreSQL not ready after ${MAX_TRIES} tries!"
        exit 1
    fi
    echo "[ENTRYPOINT] Try ${COUNT}/${MAX_TRIES} - waiting 2s..."
    sleep 2
done

echo "[ENTRYPOINT] PostgreSQL is ready!"

# Lancer Flask
echo "[ENTRYPOINT] Starting Flask on port 5000..."
exec python main.py