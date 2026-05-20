#!/usr/bin/env bash

set -euo pipefail

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:?DB_NAME is required}"
DB_USER="${DB_USER:?DB_USER is required}"
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD is required}"

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

$SUDO systemctl enable postgresql
$SUDO systemctl restart postgresql

$SUDO -u postgres psql -v ON_ERROR_STOP=1 \
  -v db_user="$DB_USER" \
  -v db_password="$DB_PASSWORD" <<'SQL'
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_password');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'db_user', :'db_password');
  END IF;
END
\$\$;
SQL

$SUDO -u postgres psql -v ON_ERROR_STOP=1 \
  -v db_name="$DB_NAME" \
  -v db_user="$DB_USER" <<'SQL'
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name') THEN
    EXECUTE format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user');
  END IF;
END
\$\$;
SQL

$SUDO -u postgres psql -v ON_ERROR_STOP=1 \
  -v db_name="$DB_NAME" \
  -v db_user="$DB_USER" <<'SQL'
DO \$\$
BEGIN
  EXECUTE format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', :'db_name', :'db_user');
END
\$\$;
SQL

if ! $SUDO -u postgres psql -v db_name="$DB_NAME" -tAc "SELECT 1 FROM pg_database WHERE datname = :'db_name'" | grep -q 1; then
  echo "PostgreSQL setup failed: database ${DB_NAME} was not created" >&2
  exit 1
fi

if ! $SUDO -u postgres psql -v db_user="$DB_USER" -tAc "SELECT 1 FROM pg_roles WHERE rolname = :'db_user'" | grep -q 1; then
  echo "PostgreSQL setup failed: role ${DB_USER} was not created" >&2
  exit 1
fi

echo "PostgreSQL setup complete for role '${DB_USER}' and database '${DB_NAME}'."
