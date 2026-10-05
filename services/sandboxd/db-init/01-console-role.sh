#!/bin/sh
# Runs once when the sandbox database volume is created.
set -eu

psql --variable=ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
     --variable=password="$SANDBOX_CONSOLE_PASSWORD" <<'SQL'
CREATE ROLE console LOGIN PASSWORD :'password';
ALTER ROLE console SET default_transaction_read_only = on;
ALTER ROLE console SET statement_timeout = '5s';
GRANT CONNECT ON DATABASE rubygopher_development TO console;
GRANT USAGE ON SCHEMA public TO console;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO console;
SQL
