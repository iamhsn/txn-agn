# Runbook

## Daily reality

- Healthchecks.io emails you if the heartbeat (every 5 min) or the nightly backup stops.
- Telegram gets a message when a service goes down, the disk passes 85%, or memory runs low, and again when it recovers.
- Stopped services are restarted automatically by the health check.

Check by hand: `sudo /opt/txn-agn/scripts/health.sh --report`

## Rebuild from scratch (target: under 1 hour)

1. Hostinger: snapshot the VPS if it still runs, then recreate it with **Ubuntu 24.04** (plain OS, no app template).
   The post-install script clones this repo and runs `scripts/bootstrap.sh`.
2. Hostinger browser terminal: `tailscale up --ssh --hostname txn-agn`, open the link, approve.
3. Re-run `bash /opt/txn-agn/scripts/bootstrap.sh` (turns on the firewall now that Tailscale is up).
4. Restore secrets: `sudo /opt/txn-agn/scripts/set-secret NAME` for each value marked YOU in `.env.example`
   (or copy the latest `env-*` backup from R2 to `/opt/txn-agn/.env`, mode 600).
5. Restore data: see "Restore the database".
6. `scripts/tailscale-serve.sh` and open the n8n editor; check workflows are active.

## Restore the database

```bash
cd /opt/txn-agn
# latest dump on the server, or download from R2: rclone copy r2:txn-agn-backups/postgres/<file> /var/backups/txn-agn/
docker compose stop n8n
gunzip -c /var/backups/txn-agn/postgres-<date>.sql.gz | docker compose exec -T postgres psql -U admin -d admin
docker compose up -d
```
The n8n encryption key in `.env` must be the same one that was in use when the backup was taken,
or saved credentials cannot be decrypted. It is in Bitwarden.

Quarterly: restore last night's dump into a throwaway container and confirm n8n starts. A backup that has never been restored is not trusted.

## Updating (monthly)

1. Hostinger snapshot.
2. Change the version in `.env` (one service at a time), then `docker compose pull && docker compose up -d`.
3. `scripts/health.sh --report`, and send a test submission to one client form.
4. Broken? Put the old version back in `.env` and `docker compose up -d`; if the database was migrated, restore the snapshot.

## Telegram chat ID

Send any message to the bot, then on the server:
`curl -s "https://api.telegram.org/bot$TOKEN/getUpdates" | jq '.result[0].message.chat.id'`

## Rotating a key

Create the new key at the provider, `set-secret NAME`, confirm it works, then revoke the old key and update Bitwarden.

## Public surface

Cloudflare Tunnel routes only these paths on `flows.techxeon.cloud` to n8n; everything else returns 404:
`/webhook/*`, `/webhook-test/*`, `/webhook-waiting/*`, `/form/*`. The n8n editor is reachable only over Tailscale.

The Cloudflare Tunnel's ingress rules live in the Cloudflare dashboard (Zero Trust → Networks → Tunnels → `txn-agn`),
not in this repo. If a new path is ever needed (for example a new n8n form route), add it there and keep the final
catch-all rule returning 404.

## n8n editor and Google OAuth

The editor is published privately with `scripts/tailscale-serve.sh` at `https://txn-agn.<tailnet>.ts.net/`.
Set the same address in `.env` so OAuth redirects land there:

```bash
sudo /opt/txn-agn/scripts/set-secret N8N_EDITOR_BASE_URL   # value: https://txn-agn.<tailnet>.ts.net/
```

In Google Cloud (OAuth client "n8n"), the authorised redirect URI must be that address followed by
`rest/oauth2-credential/callback`.

## Lead buffer (Cloudflare Worker `txn-lead-buffer`)

The Worker sits in front of `flows.techxeon.cloud/*` and is controlled by the KV key `mode`:

- `buffer`: webhook POSTs are stored in KV and answered with success; nothing reaches n8n. Use during maintenance.
- `pass`: requests go straight to n8n, and a per-minute cron replays anything stored.

Only switch to `pass` once the receiving workflows are active, or replayed leads will hit inactive webhooks and be lost.
After switching, send one test submission and confirm the row lands in the client's sheet.

## Agents (Paperclip + OpenCode)

Agents run as the Linux user `agent` (uid 2000), never as root. That user:

- has no sudo and is not in the `docker` group;
- cannot read `/opt/txn-agn/.env` (mode 600, owned by root);
- has uid 2000 on purpose: the n8n container runs as uid 1000, and a host user with that uid could stop n8n or read its files.

Paperclip runs as agent's systemd *user* service (`paperclipai.service`, kept alive by linger) on `127.0.0.1:3100`,
published privately on `https://txn-agn.<tailnet>.ts.net:8443/` by `scripts/tailscale-serve.sh`.
Its database is `paperclip` in the shared Postgres, so the nightly `pg_dumpall` backs it up.

Its settings and secrets are in `/home/agent/.config/paperclip.env` (mode 600), loaded through the drop-in
`/home/agent/.config/systemd/user/paperclipai.service.d/env.conf`. `PAPERCLIP_SECRETS_MASTER_KEY` is also in Bitwarden;
losing it makes Paperclip's stored secrets unreadable.

Working as agent (the variable lets `systemctl --user` find agent's service manager):

```bash
sudo -iu agent env XDG_RUNTIME_DIR=/run/user/$(id -u agent) bash
paperclipai service status          # supervisor + health
paperclipai service logs --lines 80
paperclipai doctor
```

Never use `pkill -u` or `killall` on the server to stop agent processes; use `paperclipai service stop`.

## SEO data workflow (n8n → agents)

`n8n/seo-data-workflow.json` is the "SEO data (agents)" workflow. It is the agents' only source of SEO facts:
sitemap/robots/llms.txt/homepage schema checks (free), DataForSEO on-page checks for up to 20 pages, Google
organic + Maps rankings for each site's keywords, and mobile PageSpeed. About $0.04 of DataForSEO per site per run.

- Called by agents from the server only: `GET http://127.0.0.1:5678/webhook/seo-data?site=<domain>` with header
  `X-SEO-Token: $SEO_DATA_TOKEN` (the token lives in agent's `paperclip.env` and in the n8n credential "SEO data token").
  The webhook path is also reachable through the tunnel, so the header check must stay on.
- n8n credentials it needs: "SEO data token" (Header Auth), "DataForSEO" (Basic Auth, API login + API password),
  "GCP API Key" (Query Auth, Name = `key`, Value = an `AIza…` key from the livo-ai-511908 project with PageSpeed
  Insights API enabled).
- Restore: n8n → Workflows → Import from file, then pick the three credentials on the nodes and activate.
- Add a site: add an entry to `SITES` in the Config node (base URL, location, brand names, 5 local keywords).
