#!/usr/bin/env bash
# Shared helpers. Source, don't run.
APP_DIR=/opt/txn-agn
set -a; [[ -f $APP_DIR/.env ]] && . "$APP_DIR/.env"; set +a

telegram() {  # telegram "message"
  [[ -n ${TELEGRAM_BOT_TOKEN:-} && -n ${TELEGRAM_CHAT_ID:-} ]] || return 0
  curl -fsS -m 10 "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=[txn-agn] $1" >/dev/null || true
}

hc() {  # hc URL [fail] [message]
  local url=${1:-}; [[ -n $url ]] || return 0
  [[ ${2:-} == fail ]] && url="$url/fail"
  curl -fsS -m 10 --retry 3 --data-raw "${3:-}" "$url" >/dev/null || true
}
