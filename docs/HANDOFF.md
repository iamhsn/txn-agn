# txn-agn handoff: SEO/AEO agents (for Claude Code)

As of 18 Oct 2026, 16:10 IST. Owner: Hassan (h@livo.digital). No secrets in this file. Keys live in Bitwarden, `/opt/txn-agn/.env` and `/home/agent/.config/paperclip.env`.

## Read this first

- Hassan is not a terminal user. Explain each command in one line before running it.
- Never print secret values. To check a secret, compare it or print its length, never the value.
- The repo `iamhsn/txn-agn` is public. Commit freely, but ask before every `git push`, and never commit anything from `.env` files.
- Don't touch the client lead workflows in n8n, the Cloudflare tunnel or the `txn-lead-buffer` Worker without asking. Leads for real clients flow through them.
- Agents run as the Linux user `agent` (uid 2000, no sudo, not in the docker group). Keep it that way. Run agent-side commands with `sudo -u agent`. Never use `pkill -u` or `killall`.

## Goal

AI agents do SEO and AEO work for Hassan's own sites and client sites from one Hostinger VPS, at the lowest cost that still produces useful work, with human approval before any change goes live. Pilot on Dhobi & Co (dhobico.com), then add 5 client sites.

## Decisions made

- **Division of labour.** n8n collects data and will do any WordPress write-back. Agents only analyse, draft and prioritise. Agents have no publish access.
- **Orchestrator.** Paperclip, one organization per site, one agent per organization.
- **Agent engine.** OpenCode with models through OpenRouter. Paperclip's OpenCode adapter only supports an OpenRouter AI connection, so every model must be an `openrouter/...` model.
- **SEO data.** DataForSEO and Google PageSpeed, called from an n8n workflow. OpenSEO is not used.
- **Server.** Stay on KVM 1 (1 vCPU, 4 GB RAM). One agent run at a time.
- **Privacy.** OpenRouter's no-training filter stays on, because client data will pass through.

## Current state

### Server
- Hostinger VPS 1305371, Ubuntu 26.04, IP 72.61.249.201. SSH and web UIs only over Tailscale (host `txn-agn`, `txn-agn.tailc354f1.ts.net`). ufw blocks everything else. 4 GB swap. About 39 GB disk free.
- Docker Compose in `/opt/txn-agn`: Postgres 16, n8n 2.44.3, cloudflared. Server copy matches the repo at commit `4a22e8f`.
- Timers: health check every 5 min (self-heal, Healthchecks.io, Telegram alerts), nightly backup at 02:30 IST (`pg_dumpall` to the server for 7 days and R2 for 30 days, which includes Paperclip's database), weekly cleanup.
- Private URLs, via `tailscale serve`: n8n editor at `https://txn-agn.tailc354f1.ts.net/`, Paperclip at `https://txn-agn.tailc354f1.ts.net:8443/`.

### Paperclip (agent manager)
- Version 2026.1012.0, managed install under `/home/agent/.paperclip/cli`. Runs as agent's systemd user service `paperclipai.service` on 127.0.0.1:3100, with linger on.
- Login-protected (`authenticated` + `private`). Sign-up is disabled. Hassan is the admin.
- Database: role and database `paperclip` in the shared Postgres.
- Settings: `/home/agent/.config/paperclip.env`, loaded by the drop-in `~/.config/systemd/user/paperclipai.service.d/env.conf`. Holds DATABASE_URL, the Paperclip secrets (the master key is also in Bitwarden), OPENROUTER_API_KEY, SEO_DATA_TOKEN, GOOGLE_GENERATIVE_AI_API_KEY and a PATH that includes `~/.local/bin`.
- Config file: `~/.paperclip/instances/default/config.json`, with `deploymentMode` set to `authenticated` and `auth.disableSignUp` set to true.
- `scripts/setup-agent.sh` rebuilds all of this on a fresh server. It doesn't set `disableSignUp`, because sign-up must stay open until the admin claims the account.
- Manage it as agent: `sudo -iu agent env XDG_RUNTIME_DIR=/run/user/2000 bash`, then `paperclipai service status|logs|restart` or `paperclipai doctor`.

### Dhobi & Co pilot
- Organization "Dhobi & Co." (task prefix DHO). Agent **SEO Lead**: OpenCode adapter, working directory `/home/agent/work/dhobico`, timeout 1200 s, timed heartbeat off.
- The agent's AI connection is Hassan's OpenRouter key, stored encrypted in Paperclip. Its model is currently `openrouter/google/gemma-4-31b-it:free`, which doesn't work (see Blocker).
- Workspace `/home/agent/work/dhobico`: `AGENTS.md` (the brief: fetch data first, never crawl, never state anything not in the data, write `reports/YYYY-MM-DD.md`, comment the summary and top 5 fixes, mark the task done), plus `data/` and `reports/`.
- Tasks DHO-1 to DHO-4 are all cancelled. No runs are queued.
- A second organization, "Livo", holds an unused Claude agent from an early attempt. Leave it.

### n8n workflow "SEO data (agents)"
- Workflow id `faKFccg43wThoWDE`, active. Source in the repo: `n8n/seo-data-workflow.json`. The runbook explains how to restore it and add sites.
- Call it from the server only: `GET http://127.0.0.1:5678/webhook/seo-data?site=dhobico.com` with header `X-SEO-Token: $SEO_DATA_TOKEN`. The path is also reachable publicly through the tunnel, so the token check must stay on.
- It returns sitemap, robots.txt, llms.txt and homepage schema checks; a DataForSEO on-page audit of up to 20 pages; Google organic and Maps rankings for 5 keywords; and mobile PageSpeed. DataForSEO costs about $0.04 per run, and the balance is $1.
- n8n credentials: "SEO data token" (Header Auth), "DataForSEO" (Basic Auth with the API login and API password), and "PageSpeed Insights API" (Query Auth, Name = `key`, an `AIza…` key from the Google Cloud project `livo-ai-511908`).
- Add a site by adding an entry to `SITES` in the Config node: base URL, location, brand names, 5 local keywords.

### What the data says about dhobico.com (17 Oct)
- **Google organic:** not in the top 30 for any of the 5 keywords. JustDial, Tumbledry, Laundroway and IndiaMART hold those spots.
- **Google Maps:** #5 for "steam ironing service hyderabad", #6 for "doorstep ironing service hyderabad", #20 for "ironing service in hyderabad". Not found for "ironing service near me" or "laundry pickup and delivery hyderabad".
- **Homepage schema:** WebSite, Organization, WebPage and BreadcrumbList are present. No LocalBusiness, and no FAQPage even though the page has a 10-question FAQ.
- **Speed:** mobile PageSpeed 67. LCP 4.8 s, CLS 0.02, TBT 280 ms. Render-blocking resources on every page.
- **Sitemap:** 37 URLs, including `/thank-you/` and `/cookie-policy/`, which shouldn't be indexed.
- **Content:** the meta description says 24–48 hours, while the page says 48 hours.
- **Already in place:** `llms.txt` exists, and the homepage title, meta description, H1 and canonical are fine.

## Blocker: no usable model until OpenRouter credit lands

The OpenRouter account has never bought credits, so:
- Only `:free` models work, capped at 50 requests a day. The counter resets at 00:00 UTC, which is 05:30 IST.
- With the no-training filter on, the only usable free model is `google/gemma-4-31b-it:free`. Google has throttled it all day ("temporarily rate-limited upstream"). Those refusals don't count against the 50.
- Hassan's Google AI Studio key is added in OpenRouter's integrations. OpenRouter ignores it until the account has bought credits ("Insufficient credits. This account never purchased credits").
- Gemini 3.8 Flash works when called directly with the Google key (`opencode run --model google/gemini-3.8-flash` replied in 85 s). Paperclip rejects it, though ("Select an AI connection compatible with the new harness and model"), because the agent's connection must be OpenRouter.

**Fix:** once Hassan's $10 OpenRouter credit lands, set SEO Lead's model to `openrouter/google/gemini-3.8-flash`. OpenRouter should then route it through his Google key. Confirm with `byok_usage_daily` from `GET https://openrouter.ai/api/v1/key`, called as agent with the OpenRouter key.

## Next steps, in order

1. **Model.** After the credit lands: Paperclip → Agents → SEO Lead → Harness / Runtime → Model → `openrouter/google/gemini-3.8-flash` → Run test → Save changes. Saving runs a "hello" probe that can take over 60 s and uses one request.
2. **Second test audit.** Create a task assigned to SEO Lead using the description below. Watch the run, then check every claim in the report against `data/<date>.json` and the facts above.
3. **Schedule and caps.** Add a weekly routine (Mondays 09:00, Asia/Kolkata). Set budgets for the company and the agent. Turn on the heartbeat only if the routine needs it.
4. **Approvals.** Send proposed fixes to Telegram for Hassan's approval. Build WordPress write-back as an n8n workflow later, run only after approval.
5. **More data.** Add Search Console (clicks, queries) and Bing to the SEO data workflow.
6. **Client sites.** For each of the 5: a `SITES` entry, a Paperclip organization with one agent, and a workspace `AGENTS.md` copied from dhobico's.

Task description for step 2 (paste as is):

```
Your working directory is /home/agent/work/dhobico. Read AGENTS.md there and follow it exactly. Keep the number of steps small:

1. Run this ONE command to fetch the facts (takes about 30 seconds):
   mkdir -p data && curl -sS -m 300 -H "X-SEO-Token: $SEO_DATA_TOKEN" "http://127.0.0.1:5678/webhook/seo-data?site=dhobico.com" -o data/$(date +%F).json && jq -c "{siteChecks, pagespeed, rankings, pages: [.pages[] | {url, title, titleLength, descriptionLength, h1, issues}]}" data/$(date +%F).json
2. Using ONLY that output, write reports/$(date +%F).md as AGENTS.md describes (3-line summary, top 5 fixes with exact paste-ready text/code, rankings table, short checklist).
3. Post the 3-line summary and top 5 fixes as a comment on this task, then set this task to done.

Do not crawl the site. Do not fetch other pages unless one specific claim needs confirming. Never state anything that is not in the data. You are read-only: never change the website.
```

## Other open work (not SEO)

- **Client-impacting, still pending:** in each of the 19 imported n8n workflows, select the new Google Sheets credential, save and activate. Then set the Worker's KV key `mode` to `pass` and test one client form. Leads are held in buffer mode until then, so don't switch to `pass` first.
- Upgrade Postgres 16 → 17 with a dump and restore, in its own session with a fresh backup.
- `scripts/finish-setup.sh` exists only on the server. Check it for secrets before committing.
- Paperclip's health check warns "No recent database backup". Its own backup feature is off; the nightly `pg_dumpall` covers the database. Silence the warning or document it.
- Connect Claude to n8n through n8n's built-in MCP server (Settings → Instance-level MCP). From Claude Code on the server use `http://127.0.0.1:5678/mcp-server/http` with the API-key token (keep it in Bitwarden). Expose only the SEO workflows, never the client lead workflows. The claude.ai connector can't reach n8n while it is Tailscale-only; publishing `/mcp-server/` through the tunnel is a later decision for Hassan.
- Decide the DataForSEO spend cap. OpenRouter's key limit is $10 a month.
- Decide who approves agent-proposed changes for each client site.

## Gotchas learned the hard way

- Paperclip retries failed runs on its own (`transient_failure_retry`, then roughly hourly `provider_quota_recovery`). Cancelling a run puts the task in a manual-review state. It's cleaner to cancel the task and create a new one.
- Agents sometimes post their comment but don't mark the task done. Paperclip then reopens it and loops. `AGENTS.md` and the task text now require marking it done.
- Paperclip API calls that change an agent's model can take over 45 s, because of the validation probe. The change only applies if the probe passes.
- Unattended `paperclipai onboard --yes` always writes `local_trusted` (no login). `setup-agent.sh` forces `authenticated` afterwards.
- Paperclip's pre-start check rejects an npm-global install. Use its managed installer (`npx paperclipai@latest install --yes`).
- npm 11 blocks install scripts by default. OpenCode needs `--allow-scripts=opencode-ai`.
- systemd user services don't see `~/.local/bin`, so it has to be on PATH in `paperclip.env`.
- The OpenCode adapter is hidden in Paperclip by default (Settings → Adapters → power icon).
- n8n credential pitfalls: DataForSEO needs the API password, not the account password. A Query Auth credential's Name must be exactly `key`. A key without a Name sends requests anonymously and hits Google's shared quota.
- The `agent` user was first created with uid 1000, the same uid the n8n container runs as, which would have let agents stop n8n or read its files. It was recreated as uid 2000. Keep the two different.

## Start Claude Code on Hassan's desktop

Claude Code runs on the desktop, not the server, and reaches the server with `ssh root@txn-agn` over Tailscale. `CLAUDE.md` in the repo root has the exact commands and rules.

1. Make sure Tailscale is connected, then check SSH works (it may ask for a one-time browser approval):
   `ssh root@txn-agn hostname` should print `srv1305371`.
2. Get the repo: `git clone https://github.com/iamhsn/txn-agn && cd txn-agn`
3. Start Claude Code in that folder (`claude` in a terminal, or open the folder in the Claude desktop app's Code tab).

First message to Claude Code: "Read CLAUDE.md, docs/HANDOFF.md and docs/RUNBOOK.md, check the server over ssh, then tell me the current state in five lines and what you'd do first."

Optional: connect Claude Code to n8n's MCP server at `https://txn-agn.tailc354f1.ts.net/mcp-server/http` (works while Tailscale is on). Expose only the SEO workflows.
