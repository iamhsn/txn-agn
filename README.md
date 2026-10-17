# txn-agn

Everything needed to rebuild Livo's agent server (Hostinger KVM 1, Ubuntu 24.04) from nothing.
If the server dies, a new one is running again by following [docs/RUNBOOK.md](docs/RUNBOOK.md) → "Rebuild from scratch".

## What runs

| Service | Purpose | Reached at |
| --- | --- | --- |
| n8n | Client form webhooks, schedules, data pulls, alerts | Webhooks: `https://flows.techxeon.cloud/webhook/...` (Cloudflare Tunnel). Editor: private, over Tailscale only |
| Postgres 16 | Data for n8n (and later Paperclip) | Server only |
| cloudflared | Outbound tunnel to Cloudflare; no inbound ports | n/a |
| Paperclip | Agent manager (phase 2) | Private, over Tailscale only |

No port is open to the internet. SSH is over Tailscale only.

## Layout

```
docker-compose.yml        core stack, versions pinned in .env
.env.example              every setting; real values live in /opt/txn-agn/.env (never committed)
config/postgres-init/     one database + user per service
scripts/bootstrap.sh      fresh Ubuntu -> working server (safe to re-run)
scripts/set-secret        add a key to .env without it showing on screen
scripts/health.sh         every 5 min: self-heal, heartbeat, Telegram alerts
scripts/backup.sh         nightly Postgres dump -> server (7 days) + Cloudflare R2
scripts/cleanup.sh        weekly disk cleanup
scripts/import-n8n-workflows.sh   load an n8n export, keeping webhook paths
systemd/                  timers for the three jobs above
docs/RUNBOOK.md           rebuild, restore, update, rotate keys
```

## Rules

- Versions are pinned. Update deliberately (RUNBOOK → "Updating").
- Secrets only in `/opt/txn-agn/.env` and Bitwarden. Never in this repo, never in chat.
- Every change to the server goes through this repo first.
