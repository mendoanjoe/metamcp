#!/usr/bin/env bash

set -euo pipefail

APP_DIR="${APP_DIR:-/opt/metamcp}"
APP_USER="${APP_USER:-$USER}"
ENV_FILE_PATH="${ENV_FILE_PATH:-/etc/metamcp/metamcp.env}"
SERVICE_NAME="${SERVICE_NAME:-metamcp}"

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

$SUDO apt-get update
$SUDO apt-get install -y ca-certificates curl gnupg rsync postgresql postgresql-contrib

curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO -E bash -
$SUDO apt-get install -y nodejs

if ! command -v pnpm >/dev/null 2>&1; then
  $SUDO corepack enable
  $SUDO corepack prepare pnpm@9.0.0 --activate
fi

$SUDO mkdir -p "$APP_DIR"
$SUDO chown -R "$APP_USER":"$APP_USER" "$APP_DIR"

$SUDO mkdir -p "$(dirname "$ENV_FILE_PATH")"
$SUDO chown root:"$APP_USER" "$(dirname "$ENV_FILE_PATH")"
$SUDO chmod 750 "$(dirname "$ENV_FILE_PATH")"

TMP_SERVICE_FILE="$(mktemp)"
sed \
  -e "s|__APP_DIR__|$APP_DIR|g" \
  -e "s|__APP_USER__|$APP_USER|g" \
  -e "s|__ENV_FILE__|$ENV_FILE_PATH|g" \
  "$APP_DIR/deploy/vps/metamcp.service" > "$TMP_SERVICE_FILE"

TARGET_SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
if ! $SUDO test -f "$TARGET_SERVICE_FILE" || ! $SUDO cmp -s "$TMP_SERVICE_FILE" "$TARGET_SERVICE_FILE"; then
  $SUDO install -m 644 "$TMP_SERVICE_FILE" "$TARGET_SERVICE_FILE"
  $SUDO systemctl daemon-reload
fi
rm -f "$TMP_SERVICE_FILE"

$SUDO systemctl enable "$SERVICE_NAME"
$SUDO systemctl enable postgresql
$SUDO systemctl restart postgresql
