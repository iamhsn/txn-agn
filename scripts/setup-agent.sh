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
  # Paperclip uses its own managed installer (~/.paperclip/cli, recorded in install.json);
  # its pre-start check refuses an npm-global copy. Remove any npm copy first.
  if [ -d ~/.local/lib/node_modules/paperclipai ]; then npm uninstall -g paperclipai >/dev/null; fi
  if [ ! -f ~/.paperclip/cli/install.json ]; then
    npx -y paperclipai@latest install --yes
  elif [ "'"${UPGRADE:-0}"'" = 1 ]; then
    paperclipai update
  fi
  [ -f ~/.paperclip/cli/install.json ] || { echo "Paperclip managed install did not complete"; exit 1; }
  if [ "'"${UPGRADE:-0}"'" = 1 ] || ! command -v opencode >/dev/null; then npm install -g --no-fund --no-audit --allow-scripts=opencode-ai opencode-ai@latest; fi
  echo "paperclipai $(paperclipai --version)"
  echo "opencode    $(opencode --version)"
'

# The service must find opencode (and other per-user tools) in ~/.local/bin; systemd's default
# PATH does not include it. EnvironmentFile values override the unit's own PATH.
grep -q '^PATH=' "$ENVFILE" || echo "PATH=/home/$AGENT/.local/bin:/usr/local/bin:/usr/bin:/bin" >> "$ENVFILE"

log "Pointing the Paperclip service at its settings file"
as_agent '
  set -e
  mkdir -p ~/.config/systemd/user/paperclipai.service.d
  printf "[Service]\nEnvironmentFile=%%h/.config/paperclip.env\n" > ~/.config/systemd/user/paperclipai.service.d/env.conf
'

CONFIG=/home/$AGENT/.paperclip/instances/default/config.json
if [[ ! -f $CONFIG ]]; then
  log "First-time Paperclip setup (writes its config; uses the database and mode from paperclip.env)"
  as_agent 'systemctl --user stop paperclipai.service 2>/dev/null; systemctl --user reset-failed paperclipai.service 2>/dev/null' || true
  # --yes runs unattended and then starts the server in the foreground; the timeout ends that
  # foreground copy once the config is written, and the service takes over below.
  as_agent 'set -a; . ~/.config/paperclip.env; set +a; timeout 150 paperclipai onboard --yes --bind loopback --no-install-service' || true
  [[ -f $CONFIG ]] || die "onboarding did not create $CONFIG; send the output above to Claude"
  echo "Config written: $CONFIG"
fi

# Unattended onboarding always writes local_trusted (no login), and config.json wins over
# PAPERCLIP_DEPLOYMENT_MODE in paperclip.env. Force login-protected mode.
if [[ $(jq -r '.server.deploymentMode' "$CONFIG") != authenticated ]]; then
  log "Switching Paperclip to login-protected (authenticated) mode"
  as_agent "cp '$CONFIG' '$CONFIG.bak' && jq '.server.deploymentMode=\"authenticated\" | .server.exposure=\"private\"' '$CONFIG.bak' > '$CONFIG'"
fi

log "Installing and starting the Paperclip service"
as_agent 'paperclipai service install' || true
as_agent 'systemctl --user daemon-reload; systemctl --user reset-failed paperclipai.service 2>/dev/null; systemctl --user enable paperclipai.service >/dev/null 2>&1; systemctl --user restart paperclipai.service' || true

log "Waiting for Paperclip to answer on 127.0.0.1:3100 (first start runs database migrations)"
ok=0
for _ in $(seq 1 60); do
  if curl -fs -m 3 -o /dev/null http://127.0.0.1:3100/api/health 2>/dev/null; then ok=1; break; fi
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
