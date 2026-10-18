# txn-agn handoff: SEO/AEO agents (for Claude Code)

As of 18 Oct 2026, 17:10 IST. Owner: Hassan (h@livo.digital). No secrets in this file. Keys live in Bitwarden, `/opt/txn-agn/.env` and `/home/agent/.config/paperclip.env`.

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
- **Orchestrator.** Paperclip, one organization per site. Each starts with one agent (SEO Lead) and grows into a small team (see Agent team plan).
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
- The agent's AI connection is Hassan's OpenRouter key, stored encrypted in Paperclip. Its model is being switched to `openrouter/google/gemini-3.8-flash` (see Model setup).
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
- **Google Maps:** #5 for "steam ironing service hyderabad", #6 for "doorstep ironing service hyderabad", #18 for "ironing service in hyderabad". Not found for "ironing service near me" or "laundry pickup and delivery hyderabad". (An earlier version of this file said #20; the data file says #18.)
- **Homepage schema:** WebSite, Organization, WebPage and BreadcrumbList are present. No LocalBusiness, and no FAQPage even though the page has a 10-question FAQ.
- **Speed:** mobile PageSpeed 67. LCP 4.8 s, CLS 0.02, TBT 280 ms. Render-blocking resources on every page.
- **Sitemap:** 37 URLs, including `/thank-you/` and `/cookie-policy/`, which shouldn't be indexed.
- **Content:** the meta description says 24–48 hours, while the page says 48 hours.
- **Already in place:** `llms.txt` exists, and the homepage title, meta description, H1 and canonical are fine.

Second reading, 18 Oct (`data/2026-10-18.json`): Maps #11, #2 and #3 for the three keywords that rank (up from #18, #5, #6). Still not in the top 30 organically for all 5. Mobile PageSpeed 57 (down from 67), LCP 4.8 s, TBT 540 ms (up from 280 ms). The drop is one reading, so don't treat it as a trend yet.

## Model setup

- The $10 OpenRouter credit landed on 18 Oct. The key has a $10 monthly limit and the no-training filter is on.
- SEO Lead's model is `openrouter/google/gemini-3.8-flash`. Hassan's Google AI Studio key is added in OpenRouter's integrations, so OpenRouter should route Gemini calls through his own Google quota now that the account has bought credits. Confirm with `byok_usage_daily` from `GET https://openrouter.ai/api/v1/key` (called as agent with the OpenRouter key).
- Why not free models: with the no-training filter on, the only free option was `google/gemma-4-31b-it:free`, which Google throttled all day on 18 Oct. Failed attempts don't count against the free quota.
- Paperclip's OpenCode adapter only accepts an OpenRouter AI connection, so a direct `google/...` model is rejected ("Select an AI connection compatible with the new harness and model") even though OpenCode itself can call Google with `GOOGLE_GENERATIVE_AI_API_KEY`.

## DHO-5 audit: what it cost and what was wrong (18 Oct)

DHO-5 on `openrouter/google/gemini-3.8-flash` finished and closed itself, so the pipeline works end to end. Report: `reports/2026-10-18.md` on the server.

**Cost.** $0.39 for 35 model steps: 226k fresh input tokens, 1.2M cache-read tokens, 10k output, 16k reasoning. Hassan's OpenRouter numbers: `usage` $0.33, `byok_usage_daily` $0.15. So about a third went through his Google key. Not explained yet. Look at `byok_usage_daily` before and after the next run to see whether it tracks the Gemini calls or only some of them.

**Where the tokens went** (from the Paperclip run log, `~/.paperclip/instances/default/data/run-logs/<company>/<agent>/<run>.ndjson`):
- Paperclip injects 5 skills into every run (`paperclip`, `paperclip-board`, `paperclip-converting-plans-to-tasks`, `paperclip-create-agent`, `para-memory-files`). The agent loaded `paperclip` (about 11k tokens) and carried it in context from step 1.
- 16 of 22 bash calls were `jq` exploration of the data file, because the fetch command printed only part of it. 4 `todowrite` calls, 2 `glob` and 2 `read` calls added more.
- It curled the homepage twice to look at the FAQ, although the brief says not to crawl.
- It spent 6 steps at the end working out how to comment and set the task done (searching for a script, printing env vars, writing a Python helper). Each step re-sends a context of 25–30k tokens.

**Fix:** (new brief deployed to the server on 18 Oct, 17:20 IST; the old one is saved as `AGENTS.md.bak-20261018`, and the 17 Oct data file is now `data/2026-10-17.json`. Skills, model and the test run still need Paperclip UI steps. `paperclipai agent skills:sync` exists but needs a board login, and the CLI returned 401 without one.) Baseline before the next run, from OpenRouter: `usage` $0.333, `byok_usage` $0.146, limit remaining $9.667.

**The fix:** `agents/dhobico/AGENTS.md` is a rewritten brief for a 4-call run. One fetch command that prints everything needed plus last run's rankings, one write, and a one-line `PATCH /api/issues/$PAPERCLIP_TASK_ID` that posts the comment and sets the task done. It bans skills, `todowrite` and crawling. To apply it:
1. Copy it to `/home/agent/work/dhobico/AGENTS.md` (owner `agent`). Also move `seo-data-test.json` to `data/2026-10-17.json` so the new brief finds a previous run.
2. In Paperclip, open SEO Lead → Skills and untick all five Paperclip skills. I haven't found how to do it outside the UI; check `paperclipai` CLI help first. If they can't be removed, the brief's "do not load skills" line is the fallback.
3. Test with a cheaper model. There is no `gemini-3.8-flash-lite` on OpenRouter. The cheapest current option is `google/gemini-3.5-flash-lite` ($0.30 in / $2.50 out per million tokens, against $0.825 / $4.125 for 3.8-flash). Compare the report against 3.8-flash before keeping it.

**Report check against `data/2026-10-18.json`.** Maps and PageSpeed numbers, the competitor names and the 18 → 11 / 5 → 2 / 6 → 3 comparison are correct. Problems:
- **LocalBusiness JSON-LD was invented.** Opening hours (08:00–20:00 every day), coordinates (17.3850, 78.4867, which is just the centre of Hyderabad) and the price range appear nowhere in the data. The area list and phone number also aren't in the data. The agent may have taken some from the homepage HTML, but none of it was checked against a source. Do not paste this block until Hassan confirms every value from the Google Business Profile.
- **">100" is wrong.** The workflow checks only Google's top 30. The right wording is "not in top 30". The new brief says so.
- **Unsupported cause:** the report says the FAQ schema is added by client-side JavaScript. Nothing in the data shows that. Check the page source before acting on fix 2.
- **Fix 3 (new H1) and the PageSpeed explanation** ("primarily caused by TBT") are opinion. Treat them as suggestions.
- **Missed data gap.** The on-page audit returned errors for 15 of 20 pages ("Invalid Field: 'url' - duplicate crawl host"), so only 5 pages were audited. The report says "all audited pages" and never mentions the gap. Every on-page issue is therefore based on 5 pages. Cause, probably: `OnPage` in the n8n workflow sends 20 URLs for one host in a single `instant_pages` request. Try one URL per request. Not fixed.
- Minor: a stray `reports/2025-10-17.md` has the wrong year. The sitemap snippet in fix 4 is a guess at the file's format; the real sitemap comes from the SEO plugin.

## Agent team plan

Each site's organization grows in this order, one step at a time, and only after the previous step works:

| Role | Added | Job |
|---|---|---|
| SEO Lead (Paperclip CEO, so it manages the others) | Now | Reads the weekly data, sets priorities, creates tasks for the others, reviews their work before it goes to Hassan |
| Writer | After the first good audit | Meta descriptions, FAQ answers and schema, service-area pages, blog posts, in each brand's voice |
| Researcher | When content production starts | Keyword gaps, questions people ask AI assistants, competitor pages. Needs DataForSEO keyword endpoints added to the n8n workflow |
| Publisher | Never an agent | WordPress write-back is an n8n workflow that runs only after Hassan approves |

n8n already does the data gathering, so there is no separate data-collection agent. Runs queue one at a time on the 1-vCPU server; cap concurrent runs at 1 per agent. Copy the proven team to the 5 client sites only after it works on Dhobi & Co.

## Next steps, in order

1. **Apply the token cut** (see "DHO-5 audit"): deploy `agents/dhobico/AGENTS.md`, remove the Paperclip skills from SEO Lead, then try `google/gemini-3.5-flash-lite`. Each change to the model runs a "hello" probe that can take over 60 s.
2. **Fix the on-page audit gap** in the n8n workflow (15 of 20 pages failed), then re-export `n8n/seo-data-workflow.json` to the repo.
3. **Third test audit.** Create a task assigned to SEO Lead using the description below. Record steps, tokens and cost from the run log, and `byok_usage_daily` before and after. Check every claim in the report against `data/<date>.json`. Target: under 10 steps and under $0.10.
4. **Schedule and caps.** Add a weekly routine (Mondays 09:00, Asia/Kolkata). Set budgets for the company and the agent. Turn on the heartbeat only if the routine needs it.
5. **Writer.** Add a Writer agent reporting to SEO Lead and test one hand-off: SEO Lead asks for a rewritten meta description, the Writer drafts it, SEO Lead reviews, Hassan approves.
6. **Approvals.** Send proposed fixes to Telegram for Hassan's approval. Build WordPress write-back as an n8n workflow later, run only after approval.
7. **More data.** Add Search Console (clicks, queries) and Bing to the SEO data workflow.
8. **Client sites.** For each of the 5: a `SITES` entry, a Paperclip organization with the proven team, and workspace `AGENTS.md` copied from `agents/dhobico/AGENTS.md`.

Task description for step 3 (paste as is). The steps live in `AGENTS.md`, so the task stays short:

```
Your working directory is /home/agent/work/dhobico. Read AGENTS.md there and follow it exactly. A normal run is 4 tool calls.
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
