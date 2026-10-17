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
