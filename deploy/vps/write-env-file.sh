#!/usr/bin/env bash

set -euo pipefail

APP_USER="${APP_USER:-$USER}"
ENV_FILE_PATH="${ENV_FILE_PATH:-/etc/metamcp/metamcp.env}"
APP_URL="${APP_URL:?APP_URL is required}"
BETTER_AUTH_SECRET="${BETTER_AUTH_SECRET:?BETTER_AUTH_SECRET is required}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:?DB_NAME is required}"
DB_USER="${DB_USER:?DB_USER is required}"
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD is required}"
EXTRA_ENV_CONTENT="${EXTRA_ENV_CONTENT:-}"

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is required to generate encoded DATABASE_URL." >&2
  exit 1
fi

escape_env_value() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

urlencode() {
  node -e 'console.log(encodeURIComponent(process.argv[1]))' "$1"
}

db_user_encoded="$(urlencode "$DB_USER")"
db_password_encoded="$(urlencode "$DB_PASSWORD")"
db_name_encoded="$(urlencode "$DB_NAME")"
database_url="postgresql://${db_user_encoded}:${db_password_encoded}@${DB_HOST}:${DB_PORT}/${db_name_encoded}"

tmp_env_file="$(mktemp)"
{
  echo "NODE_ENV=production"
  echo "APP_URL=$(escape_env_value "$APP_URL")"
  echo "NEXT_PUBLIC_APP_URL=$(escape_env_value "$APP_URL")"
  echo "BETTER_AUTH_SECRET=$(escape_env_value "$BETTER_AUTH_SECRET")"
  echo "POSTGRES_HOST=$(escape_env_value "$DB_HOST")"
  echo "POSTGRES_PORT=$(escape_env_value "$DB_PORT")"
  echo "POSTGRES_DB=$(escape_env_value "$DB_NAME")"
  echo "POSTGRES_USER=$(escape_env_value "$DB_USER")"
  echo "POSTGRES_PASSWORD=$(escape_env_value "$DB_PASSWORD")"
  echo "DATABASE_URL=$(escape_env_value "$database_url")"

  if [ -n "$EXTRA_ENV_CONTENT" ]; then
    echo
    printf "%s\n" "$EXTRA_ENV_CONTENT"
  fi
} > "$tmp_env_file"

$SUDO install -m 640 -o root -g "$APP_USER" "$tmp_env_file" "$ENV_FILE_PATH"
rm -f "$tmp_env_file"

echo "Wrote environment file to ${ENV_FILE_PATH}."
