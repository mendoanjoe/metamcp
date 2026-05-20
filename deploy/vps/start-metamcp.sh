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

PORT="$FRONTEND_PORT" pnpm --filter frontend start -- --port "$FRONTEND_PORT" &
FRONTEND_PID=$!

cleanup() {
  kill "$BACKEND_PID" "$FRONTEND_PID" 2>/dev/null || true
  wait "$BACKEND_PID" 2>/dev/null || true
  wait "$FRONTEND_PID" 2>/dev/null || true
}

trap cleanup TERM INT

wait -n "$BACKEND_PID" "$FRONTEND_PID"
status=$?
cleanup
exit $status
