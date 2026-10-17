#!/usr/bin/env bash
# Nightly: dump every Postgres database, keep 7 days on the server, copy to
# Cloudflare R2 (kept 30 days there via a bucket lifecycle rule), then ping Healthchecks.io.
# A missed or failed backup alerts you through Healthchecks.io and Telegram.
set -euo pipefail
. /opt/txn-agn/scripts/lib.sh

DIR=/var/backups/txn-agn
mkdir -p "$DIR"; chmod 700 "$DIR"
stamp=$(date +%F-%H%M)
file="$DIR/postgres-$stamp.sql.gz"

fail() { hc "${HC_BACKUP_URL:-}" fail "$1"; telegram "Backup FAILED: $1"; exit 1; }
trap 'fail "error on line $LINENO"' ERR

[[ -n ${HC_BACKUP_URL:-} ]] && hc "$HC_BACKUP_URL/start" ok
cd "$APP_DIR"
docker compose exec -T postgres pg_dumpall -U "$POSTGRES_USER" | gzip -9 > "$file.tmp"
[[ $(stat -c %s "$file.tmp") -gt 1024 ]] || fail "dump is suspiciously small"
mv "$file.tmp" "$file"
cp .env "$DIR/env-$stamp" && chmod 600 "$DIR/env-$stamp"

find "$DIR" -type f -mtime +7 -delete

where="server only (R2 not configured)"
if [[ -n ${R2_ACCESS_KEY_ID:-} && -n ${R2_SECRET_ACCESS_KEY:-} && -n ${R2_ACCOUNT_ID:-} ]]; then
  export RCLONE_CONFIG_R2_TYPE=s3 RCLONE_CONFIG_R2_PROVIDER=Cloudflare \
         RCLONE_CONFIG_R2_ACCESS_KEY_ID=$R2_ACCESS_KEY_ID RCLONE_CONFIG_R2_SECRET_ACCESS_KEY=$R2_SECRET_ACCESS_KEY \
         RCLONE_CONFIG_R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com" RCLONE_CONFIG_R2_NO_CHECK_BUCKET=true
  rclone copy "$file" "r2:${R2_BUCKET}/postgres/" --s3-no-check-bucket
  rclone copy "$DIR/env-$stamp" "r2:${R2_BUCKET}/env/" --s3-no-check-bucket
  where="server + R2"
fi

size=$(du -h "$file" | cut -f1)
hc "${HC_BACKUP_URL:-}" ok "$file ($size) -> $where"
echo "Backup OK: $file ($size) -> $where"
