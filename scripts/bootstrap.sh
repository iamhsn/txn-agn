#!/usr/bin/env bash
# Rebuilds the Livo agent server on a fresh Ubuntu 24.04 VPS.
# Safe to re-run: every step checks before it changes anything.
#
# Usage (as root, from the Hostinger browser terminal):
#   curl -fsSL https://raw.githubusercontent.com/iamhsn/txn-agn/main/scripts/bootstrap.sh -o bootstrap.sh
#   bash bootstrap.sh
# The repo is private, so in practice: git clone it first (see docs/RUNBOOK.md), then
#   bash /opt/txn-agn/scripts/bootstrap.sh
set -euo pipefail

APP_DIR=/opt/txn-agn
REPO_URL=${REPO_URL:-https://github.com/iamhsn/txn-agn.git}
SWAP_SIZE=${SWAP_SIZE:-4G}

log() { printf '\n==> %s\n' "$*"; }
[[ $EUID -eq 0 ]] || { echo "Run as root."; exit 1; }
. /etc/os-release
[[ $ID == ubuntu && $VERSION_ID == 24.04 ]] || echo "Warning: tested on Ubuntu 24.04 only (found $PRETTY_NAME)."

log "System packages and automatic security updates"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq ca-certificates curl git jq ufw unattended-upgrades rclone gnupg
dpkg-reconfigure -f noninteractive unattended-upgrades
timedatectl set-timezone Asia/Kolkata

log "Swap ($SWAP_SIZE), used only when RAM runs short"
if ! swapon --show | grep -q /swapfile; then
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
cat > /etc/sysctl.d/90-txn-agn.conf <<'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
sysctl -q --system

log "Docker"
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi
cat > /etc/docker/daemon.json <<'EOF'
{ "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "3" } }
EOF
systemctl enable --now docker
systemctl restart docker

log "Tailscale"
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
if ! tailscale status >/dev/null 2>&1; then
  if [[ -n ${TS_AUTHKEY:-} ]]; then
    tailscale up --authkey "$TS_AUTHKEY" --ssh --hostname txn-agn
  else
    echo "Open the login link below on your laptop to add this server to your tailnet."
    tailscale up --ssh --hostname txn-agn
  fi
fi

log "Repository at $APP_DIR"
if [[ ! -d $APP_DIR/.git ]]; then
  git clone "$REPO_URL" "$APP_DIR"
else
  git -C "$APP_DIR" pull --ff-only
fi
chmod +x "$APP_DIR"/scripts/*.sh "$APP_DIR"/scripts/set-secret "$APP_DIR"/config/postgres-init/*.sh

log "Secrets file"
ENV="$APP_DIR/.env"
if [[ ! -f $ENV ]]; then
  cp "$APP_DIR/.env.example" "$ENV"
fi
chmod 600 "$ENV"
setv() {  # setv NAME VALUE  (only fills empty values; never overwrites)
  local cur; cur=$(grep -E "^$1=" "$ENV" | head -1 | cut -d= -f2- | sed 's/[[:space:]]*#.*//')
  [[ -n $cur ]] && return 0
  sed -i -E "s|^$1=.*|$1=$2|" "$ENV"
}
gen() { openssl rand -hex 24; }
setv POSTGRES_PASSWORD "$(gen)"
setv N8N_DB_PASSWORD "$(gen)"
setv N8N_ENCRYPTION_KEY "$(openssl rand -hex 32)"

latest_tag() {  # latest plain x.y.z tag on Docker Hub for $1
  curl -fsSL "https://hub.docker.com/v2/repositories/$1/tags?page_size=100&ordering=last_updated" \
    | jq -r '.results[].name' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1
}
setv N8N_VERSION "$(latest_tag n8nio/n8n)"
setv CLOUDFLARED_VERSION "$(latest_tag cloudflare/cloudflared)"

log "Firewall: nothing open to the internet; SSH only over Tailscale"
if tailscale status >/dev/null 2>&1; then
  ufw --force reset >/dev/null
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow in on tailscale0
  ufw --force enable
else
  echo "Tailscale is not up yet; firewall NOT enabled (so you don't get locked out). Re-run this script after logging in."
fi

log "Timers: heartbeat (5 min), nightly backup (02:30), weekly cleanup"
install -m 0644 "$APP_DIR"/systemd/*.service "$APP_DIR"/systemd/*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now txn-health.timer txn-backup.timer txn-cleanup.timer

log "Starting the stack"
if grep -qE '^CLOUDFLARE_TUNNEL_TOKEN=$' "$ENV"; then
  echo "CLOUDFLARE_TUNNEL_TOKEN is empty: starting without the tunnel. Add it with: $APP_DIR/scripts/set-secret CLOUDFLARE_TUNNEL_TOKEN"
  (cd "$APP_DIR" && docker compose up -d postgres n8n)
else
  (cd "$APP_DIR" && docker compose up -d)
fi

log "Done"
"$APP_DIR/scripts/health.sh" --report || true
cat <<EOF

Next:
  1. Add secrets:   $APP_DIR/scripts/set-secret TELEGRAM_BOT_TOKEN   (and the others marked YOU in .env.example)
  2. n8n editor:    $APP_DIR/scripts/tailscale-serve.sh   (prints the private https address)
  3. Save the n8n encryption key in Bitwarden:  grep N8N_ENCRYPTION_KEY $ENV
EOF
