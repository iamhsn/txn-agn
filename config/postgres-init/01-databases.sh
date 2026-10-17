#!/bin/bash
# Runs once, when the Postgres volume is first created.
# One database + one user per service, so services can't read each other's data.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-SQL
  CREATE USER n8n WITH PASSWORD '${N8N_DB_PASSWORD}';
  CREATE DATABASE n8n OWNER n8n;
SQL
