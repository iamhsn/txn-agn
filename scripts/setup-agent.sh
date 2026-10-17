#!/usr/bin/env bash
# Installs the agent stack for the Linux user "agent": Paperclip (agent manager, as a
# systemd user service on 127.0.0.1:3100) and OpenCode (agent CLI), publishes Paperclip
# privately over Tailscale on :8443, and prints the one-time admin invite.
# Safe to re-run; set UPGRADE=1 to update both programs to their latest versions.
#
#   sudo bash /opt/txn-agn/scripts/setup-agent.sh
#
# Expects (done earlier, see docs/RUNBOOK.md "Agents"):
#   - user "agent" with uid 2000, no sudo, not in the docker group
#   - /home/agent/.config/paperclip.env (mode 600) with DATABASE_URL and the Paperclip secrets
#   - Node 24 in /usr/local/bin
set -euo pipefail

AGENT=agent
ENVFILE=/home/$AGENT/.config/paperclip.env
log()  { printf '\n==> %s\n' "$*"; }
die()  { printf '\nSTOPPED: %s\n' "$*"; exit 1; }

[[ $EUID -eq 0 ]] || die "run with sudo"
id -u "$AGENT" >/dev/null 2>&1 || die "user $AGENT does not exist"
AUID=$(id -u "$AGENT")
[[ $AUID -ne 1000 ]] || die "$AGENT has uid 1000, the same as the n8n container; recreate it with uid 2000"
id -nG "$AGENT" | grep -qwE 'sudo|docker|adm' && die "$AGENT is in a privileged group: $(id -nG "$AGENT")"
[[ -f $ENVFILE ]] || die "$ENVFILE is missing (step 5 of the runbook)"
command -v node >/dev/null || die "Node is not installed"
node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>24||(a===24&&b>=11)?0:1)' \
  || die "Node $(node -v) is too old; Paperclip needs 24.11 or newer"

log "Keeping agent's services running without a login"
loginctl enable-linger "$AGENT"
for _ in $(seq 1 20); do [[ -S /run/user/$AUID/bus ]] && break; sleep 1; done
[[ -S /run/user/$AUID/bus ]] || die "agent's service manager did not start (/run/user/$AUID/bus missing)"

# Run a command as agent, with its own service manager reachable.
as_agent() {
  sudo -u "$AGENT" env -i HOME=/home/$AGENT USER=$AGENT LOGNAME=$AGENT SHELL=/bin/bash \
    XDG_RUNTIME_DIR=/run/user/$AUID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$AUID/bus \
    PATH=/home/$AGENT/.local/bin:/usr/local/bin:/usr/bin:/bin \
    bash -c "$1" </dev/null
}

log "Installing Paperclip and OpenCode for $AGENT (this takes a few minutes)"
as_agent '
  set -e
  cd ~
  npm config set prefix ~/.local >/dev/null
  grep -q "\.local/bin" ~/.bashrc 2>/dev/null || echo "export PATH=\$HOME/.local/bin:\$PATH" >> ~/.bashrc
  if [ "'"${UPGRADE:-0}"'" = 1 ] || ! command -v paperclipai >/dev/null; then npm install -g --no-fund --no-audit paperclipai@latest; fi
  if [ "'"${UPGRADE:-0}"'" = 1 ] || ! command -v opencode    >/dev/null; then npm install -g --no-fund --no-audit --allow-scripts=opencode-ai opencode-ai@latest; fi
  echo "paperclipai $(paperclipai --version)"
  echo "opencode    $(opencode --version)"
'

log "Pointing the Paperclip service at its settings file"
as_agent '
  set -e
  mkdir -p ~/.config/systemd/user/paperclipai.service.d
  printf "[Service]\nEnvironmentFile=%%h/.config/paperclip.env\n" > ~/.config/systemd/user/paperclipai.service.d/env.conf
'

log "Installing and starting the Paperclip service"
as_agent 'paperclipai service install' || true
as_agent 'systemctl --user daemon-reload && systemctl --user enable paperclipai.service >/dev/null 2>&1; systemctl --user restart paperclipai.service' || true

log "Waiting for Paperclip to answer on 127.0.0.1:3100 (first start runs database migrations)"
ok=0
for _ in $(seq 1 60); do
  if curl -fsS -m 3 -o /dev/null http://127.0.0.1:3100/api/health; then ok=1; break; fi
  sleep 3
done
if [[ $ok -ne 1 ]]; then
  as_agent 'paperclipai service status' || true
  echo; echo "--- last 60 log lines ---"
  as_agent 'paperclipai service logs --lines 60' || true
  die "Paperclip did not become healthy. Send the output above to Claude."
fi
echo "Paperclip is healthy."

log "Publishing privately on Tailscale"
bash "$(dirname "$0")/tailscale-serve.sh"

log "One-time admin invite"
as_agent 'set -a; . ~/.config/paperclip.env; set +a; paperclipai auth bootstrap-ceo' \
  || echo "Could not create the invite now; Claude will give you the command to retry."

URL=$(grep -E '^PAPERCLIP_PUBLIC_URL=' "$ENVFILE" | cut -d= -f2-)
cat <<EOF

Done.
  1. On your laptop (Tailscale on), open: $URL
  2. Sign up with h@livo.digital.
  3. Open the invite link printed above, in the same browser. That account becomes the admin.
EOF
