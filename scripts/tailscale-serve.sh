#!/usr/bin/env bash
# Publishes the n8n editor privately on your tailnet (HTTPS, valid certificate).
# Only devices signed in to your Tailscale account can open it.
set -euo pipefail
tailscale serve --bg --https=443 http://127.0.0.1:5678
echo "n8n editor (private): https://$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')/"
