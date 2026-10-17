#!/usr/bin/env bash
# Publishes the private web apps on your tailnet (HTTPS, valid certificate).
# Only devices signed in to your Tailscale account can open them.
#   n8n editor  -> https://<name>.ts.net/        (n8n on 127.0.0.1:5678)
#   Paperclip   -> https://<name>.ts.net:8443/   (Paperclip on 127.0.0.1:3100, once installed)
set -euo pipefail
NAME=$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')

tailscale serve --bg --https=443 http://127.0.0.1:5678
echo "n8n editor (private): https://$NAME/"

if curl -fsS -m 3 -o /dev/null http://127.0.0.1:3100/api/health 2>/dev/null; then
  tailscale serve --bg --https=8443 http://127.0.0.1:3100
  echo "Paperclip (private):  https://$NAME:8443/"
else
  echo "Paperclip is not running on 127.0.0.1:3100 yet; skipped. Re-run this script after installing it."
fi
