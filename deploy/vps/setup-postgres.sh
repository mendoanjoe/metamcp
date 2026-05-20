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

escape_sql_literal() {
  printf "%s" "$1" | sed "s/'/''/g"
}

db_name_sql="$(escape_sql_literal "$DB_NAME")"
db_user_sql="$(escape_sql_literal "$DB_USER")"
db_password_sql="$(escape_sql_literal "$DB_PASSWORD")"

$SUDO systemctl enable postgresql
$SUDO systemctl restart postgresql

$SUDO -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${db_user_sql}') THEN
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '${db_user_sql}', '${db_password_sql}');
  ELSE
    EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', '${db_user_sql}', '${db_password_sql}');
  END IF;
END
\$\$;
SQL

$SUDO -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${db_name_sql}') THEN
    EXECUTE format('CREATE DATABASE %I OWNER %I', '${db_name_sql}', '${db_user_sql}');
  END IF;
END
\$\$;
SQL

$SUDO -u postgres psql -v ON_ERROR_STOP=1 <<SQL
GRANT ALL PRIVILEGES ON DATABASE "${DB_NAME}" TO "${DB_USER}";
SQL

if ! $SUDO -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name_sql}'" | grep -q 1; then
  echo "PostgreSQL setup failed: database ${DB_NAME} was not created" >&2
  exit 1
fi

if ! $SUDO -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${db_user_sql}'" | grep -q 1; then
  echo "PostgreSQL setup failed: role ${DB_USER} was not created" >&2
  exit 1
fi

echo "PostgreSQL setup complete for role '${DB_USER}' and database '${DB_NAME}'."
