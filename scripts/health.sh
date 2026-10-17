#!/usr/bin/env bash
# Runs every 5 minutes. Pings Healthchecks.io when all is well; reports a failure
# (and alerts Telegram) when a service is down or the disk/memory is close to full.
# If the whole server dies, the pings stop and Healthchecks.io alerts you.
#   health.sh            normal timer run
#   health.sh --report   print status to the terminal
set -uo pipefail
. /opt/txn-agn/scripts/lib.sh

problems=()
cd "$APP_DIR" || exit 1

for svc in postgres n8n cloudflared; do
  grep -qE '^CLOUDFLARE_TUNNEL_TOKEN=.+' .env || [[ $svc != cloudflared ]] || continue
  state=$(docker compose ps --format '{{.State}} {{.Health}}' "$svc" 2>/dev/null)
  [[ $state == running* && $state != *unhealthy* ]] || problems+=("$svc: ${state:-not running}")
done

disk=$(df --output=pcent / | tail -1 | tr -dc 0-9)
(( disk < 85 )) || problems+=("disk ${disk}% full")

mem_avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
swap_used=$(free -m | awk '/Swap/{print $3}')
(( mem_avail > 250 || swap_used < 2500 )) || problems+=("memory low: ${mem_avail} MB free, ${swap_used} MB swap used")

msg="disk ${disk}% | RAM free ${mem_avail} MB | swap used ${swap_used} MB"
if [[ ${1:-} == --report ]]; then
  docker compose ps --format 'table {{.Service}}\t{{.State}}\t{{.Health}}'
  echo "$msg"
  ((${#problems[@]})) && printf 'PROBLEM: %s\n' "${problems[@]}"
  exit 0
fi

state_file=/run/txn-health.last
if ((${#problems[@]})); then
  text=$(printf '%s; ' "${problems[@]}")
  hc "${HC_HEARTBEAT_URL:-}" fail "$text $msg"
  # Alert once per new problem, not every 5 minutes.
  [[ $(cat $state_file 2>/dev/null) == "$text" ]] || telegram "Problem: $text"
  echo "$text" > $state_file
  # Self-heal: bring stopped services back.
  docker compose up -d >/dev/null 2>&1
else
  hc "${HC_HEARTBEAT_URL:-}" ok "$msg"
  [[ -s $state_file ]] && telegram "Recovered. $msg"
  : > $state_file
fi
