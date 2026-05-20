#!/usr/bin/env bash

set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$APP_DIR"

FRONTEND_PORT="${PORT:-12008}"

if [ ! -f apps/backend/dist/index.js ]; then
  echo "Missing backend build output: apps/backend/dist/index.js" >&2
  exit 1
fi

if [ ! -d apps/frontend/.next ]; then
  echo "Missing frontend build output: apps/frontend/.next" >&2
  exit 1
fi

node apps/backend/dist/index.js &
BACKEND_PID=$!

pnpm --filter frontend start -- --port "$FRONTEND_PORT" &
FRONTEND_PID=$!

cleanup() {
  kill "$BACKEND_PID" "$FRONTEND_PID" 2>/dev/null || true
  sleep 2
  kill -9 "$BACKEND_PID" "$FRONTEND_PID" 2>/dev/null || true
  wait "$BACKEND_PID" 2>/dev/null || true
  wait "$FRONTEND_PID" 2>/dev/null || true
}

trap cleanup EXIT TERM INT

while true; do
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    if wait "$BACKEND_PID"; then
      first_status=0
    else
      first_status=$?
    fi
    break
  fi

  if ! kill -0 "$FRONTEND_PID" 2>/dev/null; then
    if wait "$FRONTEND_PID"; then
      first_status=0
    else
      first_status=$?
    fi
    break
  fi

  sleep 1
done

if [ "$first_status" -ne 0 ]; then
  exit "$first_status"
fi

exit 1
