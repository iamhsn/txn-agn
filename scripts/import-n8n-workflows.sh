#!/usr/bin/env bash
# Imports an n8n workflow export (JSON array) into the running n8n, keeping IDs and
# webhook paths so client forms keep posting to the same URLs.
#   import-n8n-workflows.sh /path/to/n8n-workflows.json
# Archived workflows are skipped. Workflows come in inactive; reconnect the
# "Google Sheets account" credential, then activate (see docs/RUNBOOK.md).
set -euo pipefail
. /opt/txn-agn/scripts/lib.sh
SRC=${1:?usage: import-n8n-workflows.sh FILE}
tmp=$(mktemp)
jq '[.[] | select(.isArchived != true)]' "$SRC" > "$tmp"
echo "Importing $(jq length "$tmp") workflows (archived ones skipped)."
cd "$APP_DIR"
# Pipe the file in rather than `docker compose cp`: cp lands it owned by root and
# n8n (running as user node) then fails with EACCES.
docker compose exec -T n8n sh -c 'cat > /tmp/workflows.json && n8n import:workflow --input=/tmp/workflows.json; rc=$?; rm -f /tmp/workflows.json; exit $rc' < "$tmp"
rm -f "$tmp"
echo "Done. Webhook paths to verify:"
jq -r '.[] | select(.isArchived != true) | .name as $n | .nodes[] | select(.type=="n8n-nodes-base.webhook") | "  \($n): /webhook/\(.parameters.path)"' "$SRC"
