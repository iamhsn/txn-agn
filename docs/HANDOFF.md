# txn-agn handoff: SEO/AEO agents (for Claude Code)

As of 18 Oct 2026, 17:35 IST. Owner: Hassan (h@livo.digital). No secrets in this file. Keys live in Bitwarden, `/opt/txn-agn/.env` and `/home/agent/.config/paperclip.env`.

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
- **SEO data.** OpenSEO (hosted, through its MCP endpoint, called from n8n) and Google PageSpeed. DataForSEO was removed on 19 Oct 2026 (see "OpenSEO switch").
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
- A second organization, "Livo", holds an unused Claude agent from an early attempt. Leave it. A third, "ACG United" (prefix ACG, one SEO Lead agent, one onboarding task), also exists and isn't described anywhere else. Ask Hassan what it is for.

### n8n workflow "SEO data (agents)"
- Workflow id `faKFccg43wThoWDE`, active. Source in the repo: `n8n/seo-data-workflow.json`. The runbook explains how to restore it and add sites.
- Call it from the server only: `GET http://127.0.0.1:5678/webhook/seo-data?site=dhobico.com` with header `X-SEO-Token: $SEO_DATA_TOKEN`. The path is also reachable publicly through the tunnel, so the token check must stay on.
- It returns sitemap, robots.txt, llms.txt and homepage schema checks; the latest OpenSEO site audit (`onpage`); Google organic positions from the OpenSEO rank tracker and Maps positions from OpenSEO local SERP, for 10 keywords; AI answer visibility (`openseo.aiVisibility`, empty until someone runs an AI check); and mobile PageSpeed. A call takes 80 to 100 s and uses roughly 30 OpenSEO credits (20 local SERP calls plus tracker reads).
- n8n credentials: "SEO data token" (Header Auth), "OpenSEO" (Header Auth, Name `x-api-key`, Value = a personal OpenSEO API key; `Authorization: Bearer` was rejected with 401 on the hosted endpoint) and "PageSpeed Insights API" (Query Auth, Name = `key`, an `AIza…` key from the Google Cloud project `livo-ai-511908`). The DataForSEO credential was deleted.
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

**Fix, applied 18 Oct (17:20 to 17:30 IST).** New brief `agents/dhobico/AGENTS.md` is on the server (old one saved as `AGENTS.md.bak-20261018`; the 17 Oct data file moved to `data/2026-10-17.json`). In Paperclip (Dhobi & Co. → SEO Lead) four of the five skills are switched off and `first-task` stays off; Paperclip switches the core `paperclip` skill back on whenever it is turned off, so the brief's "do not load skills" line covers that one. Model is now `openrouter/google/gemini-3.5-flash-lite`. There is no `gemini-3.8-flash-lite`; 3.5 flash-lite costs $0.30 in / $2.50 out per million tokens, against $0.825 / $4.125 for 3.8-flash. Saving the model took over 2 minutes (the probe).

**Result, task DHO-6:** 6 steps, 5 tool calls (4 bash, 1 write), 31.5k fresh input tokens (was 226k), 73k cache-read, 1.8k output, 6.8k reasoning. Run cost $0.033; OpenRouter `usage` rose from $0.333 to $0.371 and `byok_usage` from $0.146 to $0.164, so BYOK is again about half. Under 1 minute. The agent followed the brief, wrote "not in top 30", and reported the 13 skipped pages. Quality problems:
- **Previous-run bug in the brief (fixed in the repo and on the server after this run):** it picked the newest file in `data/`, which was today's file from DHO-5, so DHO-6 said "unchanged since previous" for Maps ranks that had in fact moved since 17 Oct. It now picks the newest file that isn't today's.
- It invented image paths in two fixes (`/images/hero-steam.jpg`). A rule against this is now in the brief.
- Its top 5 is weaker than DHO-5's: noindex for thank-you and cookie pages, an `&amp;` in the `llms.txt` first line, and alt text. It left out LocalBusiness and FAQPage schema. Part of the reason is the `TODO_CONFIRM` rule; some may be the cheaper model. Compare a 3.8-flash run on the same brief before choosing a model.
- The `&amp;` finding may be an artefact of how the workflow reads `llms.txt` (it escapes HTML). Check the real file before acting.
- DHO-6's report overwrote DHO-5's `reports/2026-10-18.md`. DHO-5's report is no longer on the server; the review below is the record. The brief should write a new file per run (for example add the time) if you want to keep both.

**Report check against `data/2026-10-18.json`.** Maps and PageSpeed numbers, the competitor names and the 18 → 11 / 5 → 2 / 6 → 3 comparison are correct. Problems:
- **LocalBusiness JSON-LD was invented.** Opening hours (08:00–20:00 every day), coordinates (17.3850, 78.4867, which is just the centre of Hyderabad) and the price range appear nowhere in the data. The area list and phone number also aren't in the data. The agent may have taken some from the homepage HTML, but none of it was checked against a source. Do not paste this block until Hassan confirms every value from the Google Business Profile.
- **">100" is wrong.** The workflow checks only Google's top 30. The right wording is "not in top 30". The new brief says so.
- **Unsupported cause:** the report says the FAQ schema is added by client-side JavaScript. Nothing in the data shows that. Check the page source before acting on fix 2.
- **Fix 3 (new H1) and the PageSpeed explanation** ("primarily caused by TBT") are opinion. Treat them as suggestions.
- **Missed data gap.** The on-page audit returned errors for 15 of 20 pages ("Invalid Field: 'url' - duplicate crawl host"), so only 5 pages were audited. The report says "all audited pages" and never mentions the gap. Every on-page issue is therefore based on 5 pages. Cause, probably: `OnPage` in the n8n workflow sends 20 URLs for one host in a single `instant_pages` request. Try one URL per request. Not fixed.
- Minor: a stray `reports/2025-10-17.md` has the wrong year. The sitemap snippet in fix 4 is a guess at the file's format; the real sitemap comes from the SEO plugin.

## OpenSEO switch, 19 Oct 2026

Done:
- **DataForSEO is gone.** DataForSEO needed a $50 minimum top-up and the $1 balance ran out (HTTP 402). The workflow no longer calls it, and the n8n credential "DataForSEO" was deleted after a successful test run for both sites. Backups of every earlier version: `/root/n8n-backups/` on the server (the last DataForSEO version is `seo-data-2026-10-19-2016-pre-dfs-removal.json`).
- **New flow in `n8n/seo-data-workflow.json`:** Webhook, Config, Discover (free checks), PageSpeed, then OpenSEO calls through n8n's MCP Client node: `list_site_audits`, `run_site_audit` (only when needed), `get_audit_issues`, `get_rank_tracker` (twice: list trackers, then read one), `get_ai_visibility_results`, and `get_local_serp_results` once per keyword. Response fields: `onpage`, `pagesAudited`, `pagespeed`, `rankings.maps`, `openseo.rankings`, `openseo.aiVisibility`, `siteChecks`.
- **Audit timing.** A site audit starts on the first Monday of the month (Asia/Kolkata), or when a site has no completed audit yet, and never when one ran or started in the last 24 hours. Every call reads the latest completed audit, so a first-Monday call returns the previous audit and the new one shows from the next call. Audits crawl up to 50 pages (`auditMaxPages` in Config). Dhobi: 38 pages; Ladva: 50 of 196 sitemap URLs.
- **Maps positions** use `rank_absolute` and match on the domain or the brand name. `Config` holds a search origin per site (`near`: city centre, zoom 12). These are the city centre, not the business address.
- **Project IDs** are in Config: dhobico.com `9d34bb48-8c2f-48c8-aa42-dcfe4f1faadc`, ladvalaw.com `04765c8e-cd37-48bf-bf48-011aafe72a07`. Each has one weekly rank tracker with 10 keywords (mobile, top 30).
- **Snapshots.** Table `seo_snapshots` (database `admin`: site, taken_at, source, data jsonb, index on site and taken_at). Every webhook call inserts one row per site (`source` = `openseo`, `data` = the full response) through the node "Save snapshot" (credential "Postgres SEO", host `postgres`, database `admin`, user `admin`). A final "Output" node returns the Summary, so a failed insert never breaks the response. Tested 19 Oct: one row each for dhobico.com and ladvalaw.com. Test calls also write rows, so filter out odd ones by `taken_at` if you chart trends.
- **Brief** (`agents/seo-lead.md`) reads `onpage` and the OpenSEO fields and has an "AI answers" section. Both workspace `AGENTS.md` files were replaced; the old versions are `AGENTS.md.bak-20261019b`.

Not done:
- **Paperclip audit tasks with the new brief.** Not run. The next Monday 09:00 routine will be the first real test. Check that the report uses `onpage`, `rankings.maps` and the "No AI visibility data yet" line, and that it states the audit date.
- **AI answer visibility is empty.** Nobody has configured an AI visibility tracker or run a check in OpenSEO. Running a check spends credits (use `estimate_ai_visibility_cost` first).
- **Backlinks and keyword ideas** from the plan are not in the workflow yet.
- **Ladva Law's Maps data is empty** for all 10 keywords. That is plausible for a law firm, but check one by hand in Google Maps before the SEO Lead tells a client so.
- The scratch workflow "tmp OpenSEO tool list" was deleted after use.

## Team, Reviewer and routines, 19 to 20 Oct 2026

Built (details in `agents/README.md`):
- **Agents per site:** SEO Lead and Developer on `claude-haiku-5.5`, Writer on `google/gemini-3.5-flash-lite`. Budgets $0.75 / $0.50 / $0.25, company hard stop $1.50. Heartbeat off, 1 concurrent run, nobody except SEO Lead can create agents. **Deviations from the request:** SEO Lead and Developer stay on Haiku, not `gemini-3.8-flash`, because 3.8 flash failed twice on 19 Oct ("corrupted thought signature") and costs about 8 times more. Writer is not on a free model: the only free tool-capable model this account may use that worked in a direct test, `google/gemma-4-26b-a4b-it:free`, stalled for over 5 minutes as a Writer (it also added "free" to a meta description, which was not in the facts). `gemini-3.8-flash-lite` does not exist.
- **Files:** `agents/developer.md`, `scripts/check-copy.sh` (the Reviewer, copied to each workspace as `bin/check-copy.sh`), `agents/seo-lead.md` (new report sections, Writer to check-copy to Developer flow), `agents/writer.md`, `scripts/site-workspace.sh` (now also creates `writer/`, `developer/`, `bin/`, `drafts/`; optional 4th argument is the WordPress base URL). Ladva's base is `https://www.ladvalaw.com`.
- **Backlinks** added to the n8n webhook (`openseo.backlinks`: overview, newest 100 rows, new links, lost links, spam flag). Refreshed on the first Monday or when none is saved, otherwise the last saved copy is reused (it is read back from `seo_snapshots`). About 80 credits per site per refresh.
- **n8n workflow "SEO monthly pull"** (`n8n/seo-monthly-pull.json`, id `seoMonthlyPull01`): Mondays 07:00 Asia/Kolkata, acts only on the first Monday, calls the webhook for both sites.
- **Paperclip routines:** weekly Mon 09:00 (existing) and monthly Mon 10:00 (new; the brief makes the agent stop unless it is the first Monday, because cron cannot say "first Monday"). Dhobi monthly routine `988742d3-f61b-4ac4-91c2-f55a9f57a910`, Ladva `650d44ba-4c3c-40fb-bb2e-c6d5bd9840a2`. OpenSEO's own rank tracker already runs weekly at Mon 06:00 IST.
- **Field names differ from the request:** the audit is `onpage` (not `siteAudit`); `pagesAudited` is the pages crawled by the audit.

Test results:
- **Weekly audit, both sites:** about 3 to 4 minutes each, about $0.010 per site (OpenRouter usage rose $0.020 for the pair). Numbers in both reports match the data: PageSpeed, every Maps and organic position, audit issues, backlink totals, spam counts, schema gaps. **Wrong or weak statements:** Dhobi called the backlink copy "last month's refresh" (it is from earlier that day), its summary proposed a disavow review while its Backlinks section said none, it suggested a 48-character title (rule is 50 to 60) and skipped the Writer for it, and it wrote "38 of 37 pages". Ladva said "100 of 100 new links" (30 are new; 100 is the row count) and "a normal run of 3 to 15 a month" (the data shows 12, 45 and 195 for Jul to Sep). The brief now has rules against each of these; not re-run.
- **A stale-data bug found and fixed:** the first test used the old data file. The fetch took longer than OpenCode's 120 s tool timeout, the agent silently used the morning's file, and wrote an old-data report. The brief now deletes today's file first, asks for `timeout: 300000`, and blocks the task if the fetch fails.
- **Dry run, Dhobi homepage meta description:** Writer task done in 52 s, draft `PASS` in `check-copy.sh`; the wording was clumsy ("our doorstep ironing service hyderabad") but used only the given facts. Developer task blocked in 91 s for $0.011 with "needs WP credentials" and also noted the missing SEO plugin field name. Nothing was written to WordPress.
- Cost figures: SEO Lead audit about $0.010, Developer blocked run $0.011, Writer under $0.005 per draft.

Blocked or open:
- **WordPress access.** No application passwords exist. Create one per site (WordPress, Users, Profile, Application Passwords), add `WP_DHOBICO_USER`, `WP_DHOBICO_APP_PASSWORD`, `WP_LADVALAW_USER`, `WP_LADVALAW_APP_PASSWORD` to `/home/agent/.config/paperclip.env`, and restart Paperclip. Until then the Developer cannot work.
- **SEO plugin field.** Which plugin (Yoast, Rank Math) stores meta descriptions, and whether its field is exposed over REST, is unknown. Developer blocks meta changes until a task names the field.
- **Keyword research** in the monthly task is not automated; the brief says so. Add OpenSEO `research_keywords` to the monthly n8n pull if wanted.
- **AI answers** are empty until an AI visibility tracker exists in OpenSEO.
- **Dhobi SEO Lead budget:** $0.52 of $0.75 is already spent this month (the early DHO-5 run was $0.39). It will stop at $0.75; raise it if needed.
- The Writer on flash-lite is untested on a law-firm draft. Test one before the Ladva Writer handles anything real.

## Four-site run, 20 Oct 2026

**Setup done.** `acre.realty` and `acgunited.com` are in the n8n workflow (`SITES` entries built from their OpenSEO projects: tracker keywords, Houston location, competitors from the project context). ACG's Maps check covers two keywords only (`localKeywords`), because it is a national B2B site. Every site now returns a `competitors` list. Both new sites return data (rankings, Maps, backlinks); their first OpenSEO site audit started on 20 Oct, so `onpage` says "no completed audit yet" until it finishes. A first import of the workflow created a duplicate (`SMH1BTz2fas7nOWJ`); it was deleted and the real one (`faKFccg43wThoWDE`) re-imported. Repo JSON carries no `id`: add `"id":"faKFccg43wThoWDE","active":true` to the copy before `n8n import:workflow`.

**Paperclip.** New organization "ACRE Realty" (SEO Lead, Writer, Developer, $1.50 stop) and, in "ACG United", a new OpenCode SEO Lead plus Writer and Developer (the original Claude SEO Lead is paused). Weekly (Mon 09:00) and monthly (Mon 10:00) routines created for both. Workspaces `/home/agent/work/acre` and `/home/agent/work/acgunited` rendered. WordPress app passwords for dhobico.com, acre.realty and acgunited.com are in `paperclip.env` (editor role); all three pass `GET /users/me`. Ladva has none.

**ACRE and ACG AI connection (fixed).** Their OpenRouter connections are organization-shared, not owned by Hassan, so he cannot make them his "personal default" and every run stopped with "selected AI account is unavailable". All six agents there now use `aiConnection` mode `shared` (connection ids `0b386662-…` ACRE, `a7ade0df-…` ACG). A failed run also leaves the agent in `error`; `paperclipai agent resume <id>` clears it. The ACG SEO Lead, ACRE SEO Lead and ACG SEO Lead 2 carry `dangerouslySkipPermissions` like Dhobi's; the new Writers and Developers do not. ACG agents are named "SEO Lead 2", "Writer 2", "Developer 2" (rename in the UI).

**Reports, Dhobi and Ladva.** First run and a rerun with the new Competitors section. Everything checked against the data file matched (PageSpeed, backlink totals, new and spam counts, issue counts, audit date, schema types, organic positions, Ladva Maps). Wrong claims: in the rerun, Dhobi's Competitors section gave our Maps position as #10, #9 and #2 where the data says 11, 8 and 4 (the agent worked it out from `top3`); the brief now says to quote `position` exactly. Not re-run. The first run lacked competitors and AI-answer names; AI answers still read "No AI visibility data yet" because no AI tracker exists.

**Delegation.** Dhobi: one Writer draft (title for the Dairy Farm page, 57 characters, check-copy PASS) and one Developer task (DHO-21), which could not apply it. Two reasons: the page is a `dc_location` custom post type, which the Developer cannot reach through `pages` or `posts`, and dhobico.com has no SEO plugin (Oxygen/Breakdance only), so there is no meta key. Ladva: nothing delegated (no facts or WP credentials). **No WordPress drafts were created.** Other fixes need Hassan or the client: LocalBusiness and FAQPage schema (business details and FAQ text are not in the data), the thank-you page noindex, and the disavow decision.

**Cost (OpenRouter usage delta).** First audit pass, two sites running: $0.023. Rerun, two reports: $0.057. Delegation, two tasks including the Writer and Developer: $0.095. About $0.175 in total; no single run came near $0.20.

**ACRE and ACG reports.** Both ran (ACR-5, ACG-6) and match their data (positions, backlink totals and spam counts, issue counts, PageSpeed, schema). Gaps: both said the tracked competitor list was missing, because the fetch `jq` filter dropped `competitors` (now added); ACRE omitted PageSpeed (the brief now requires it in the Summary). ACRE shows no organic or Maps ranking for any of its 10 keywords; ACG ranks for 4 of 10 (best: "spectrum authorized dealer" at 9). Neither has AI visibility data.

**Delegation, ACRE and ACG.** ACRE: nothing delegated (alt text needs image descriptions, meta descriptions and LocalBusiness need facts, H1 work is a template change). ACG: one Writer title for the Reseller Programs page (59 characters, check-copy PASS) and one Developer task (ACG-9), which blocked because the title is an SEO-plugin field and none of the four sites has an SEO plugin (all are Oxygen or Breakdance). **Result for all four sites: zero WordPress drafts.** Reason in short: the fixes the data supports are meta descriptions and SEO titles, and the sites have nowhere to store them through the REST API, plus custom post types on Dhobi and ACRE.

**Cost (OpenRouter usage delta).** Dhobi and Ladva: first pass $0.023, rerun $0.057, delegation $0.095. ACRE and ACG: audits $0.064, delegation $0.103. About $0.34 in total; no single run was near $0.20.

**Next.** Decide how meta descriptions and SEO titles get written: install an SEO plugin (Yoast, Rank Math or SEOPress) on the four sites and expose its fields, (no custom code; see the rule in CLAUDE.md). Until then the Developer can only draft new posts. Also: add an AI visibility tracker for the four projects; Ladva WordPress credentials; give the SEO Leads the facts they lack (business details for LocalBusiness schema, FAQ text, image descriptions). Re-render workspaces after any `agents/*.md` change, from a clean checkout of the repo.

## AI visibility and The SEO Framework, 21 Oct 2026

**AI trackers already existed.** All four OpenSEO projects have a weekly tracker (ChatGPT, Gemini, Google AI Overviews, 5 prompts each, next check 27 Oct) and a 19 Oct run. The workflow said "No AI visibility data yet" because `get_ai_visibility_results` returns nothing unless it gets a `runId`. Fixed: a new node "OpenSEO AI tracker" reads `get_ai_visibility_tracker`, and "OpenSEO AI" passes the newest completed or partial run id (limit 50, the tool maximum). Dhobi now returns 15 rows: dhobico.com is mentioned and cited in none of its 10 answers (5 Google AI Overview queries gave no answer). ACRE's 19 Oct run failed completely, so a one-off check ($0.09) was started on 21 Oct. Credits: about 8,430 left.

**The SEO Framework.** Dhobico.com and acre.realty pages show it in their HTML; Hassan says acgunited.com has it too. It stores the SEO title and meta description in post meta `_genesis_title` and `_genesis_description`. **Neither key is registered for the REST API on any of the three sites** (the `meta` schema lists only Oxygen keys), so a Developer write would be dropped without an error. **Decision (Hassan, 21 Oct): no custom plugins or must-use plugins, ever.** So the Developer only proposes SEO titles and meta descriptions, and Hassan pastes them into the SEO Framework box. Revisit only if an existing, maintained plugin or the already installed Agent Connector / Universal Abilities plugins expose these fields.

**Status check from the cloud session, 21 Oct.** OpenSEO projects: dhobico.com `9d34bb48-…`, ladvalaw.com `04765c8e-…`, acre.realty `572bf04b-…`, acgunited.com `0f034fbb-…`. Each has a weekly rank tracker (10 keywords, Mon 06:00 IST, next 26 Oct), a business overview and 6 to 8 competitors set by Hassan (Ladva also gjel.com and bestattorney.com). 19 Oct AI results: Ladva cited once (Google AI Overview, "Uber or Lyft accident attorney San Francisco"); ACG 14 of 15 answers collected. ACRE re-run id `b4aa32d7-8560-4529-b448-977d7c4d2204`.

## Next steps (21 Oct onwards)

1. **Unblock the Developer** (zero WordPress drafts so far). SEO titles and meta stay proposals (no custom plugins). Check whether the installed Agent Connector / Universal Abilities plugins can write The SEO Framework fields; if so, plan it and ask Hassan. Allow the Developer to target the custom post types (`dc_location` on Dhobi, ACRE's listing types). Ask Hassan before installing anything on client sites.
2. **AI data in reports.** Re-run one audit per site and check the AI answers section names competitors.
3. **Ladva.** Confirm the CMS; if WordPress, create the application password and add `WP_LADVALAW_*` to `paperclip.env`.
4. **Facts the agents lack.** Collect from Hassan, per site: business address, phone and hours (LocalBusiness schema), FAQ text (FAQPage), image descriptions. Store as `facts.md` in each workspace and point the brief at it.
5. **Check the first scheduled runs** on Mon 26 Oct (09:00 IST): all 4 routines fired, cost per run under $0.02, OpenSEO credits used.
6. **Refresh "Current state" at the top of this file.** It still describes 18 Oct.
7. **Budgets.** Dhobi's SEO Lead had $0.52 of $0.75 spent by 19 Oct; check and raise if the Monday run would stop.

## Agent team plan

Each site's organization grows in this order, one step at a time, and only after the previous step works:

| Role | Added | Job |
|---|---|---|
| SEO Lead (Paperclip CEO, so it manages the others) | Now | Reads the weekly data, sets priorities, creates tasks for the others, reviews their work before it goes to Hassan |
| Writer | After the first good audit | Meta descriptions, FAQ answers and schema, service-area pages, blog posts, in each brand's voice |
| Researcher | When content production starts | Keyword gaps, questions people ask AI assistants, competitor pages. Needs OpenSEO keyword tools (`research_keywords`, `get_keyword_metrics`) added to the n8n workflow |
| Publisher | Never an agent | WordPress write-back is an n8n workflow that runs only after Hassan approves |

n8n already does the data gathering, so there is no separate data-collection agent. Runs queue one at a time on the 1-vCPU server; cap concurrent runs at 1 per agent. Copy the proven team to the 5 client sites only after it works on Dhobi & Co.

## Phase 2 setup, 19 Oct 2026 (01:20 to 01:55 IST)

Done:
- Repo pulled here (3 local commits rebased onto origin) and on the server. `scripts/site-workspace.sh` ran for dhobico.com and ladvalaw.com. It replaced `/home/agent/work/dhobico/AGENTS.md` with the template from `agents/seo-lead.md`; the old brief is in `AGENTS.md.bak-20261018` and `agents/dhobico/AGENTS.md`.
- n8n "SEO data (agents)" now has ladvalaw.com in Config. The CLI import deactivated the workflow, so it was reactivated and n8n restarted. Backup of the previous version: `/root/n8n-backups/seo-data-2026-10-19-0122.json` on the server. Webhook test for ladvalaw.com returned rankings (HTTP 200).
- Paperclip board access: board API key "claude-code" for the `agent` user, created via `paperclipai connect --persona board` (approval link must use the Tailscale address `https://txn-agn.tailc354f1.ts.net:8443/cli-auth/...`, not localhost). Expires 17 Nov 2026.
- Both companies: budget $1/month. SEO Lead: first `openrouter/google/gemini-3.8-flash` (now DeepSeek, see below), work directory per site, budget $0.75, max 1 concurrent run, heartbeat off. Ladva's SEO Lead also got skills off, 900 s timeout and `dangerouslySkipPermissions` like Dhobi's. New Writer agents (OpenCode, `openrouter/google/gemini-3.5-flash-lite`, `/home/agent/work/<site>/writer`, $0.25, 1 run, heartbeat off, reports to SEO Lead). `gemini-3.8-flash-lite` does not exist. Writers inherited `canCreateAgents: true`; consider turning that off.

Failed (first attempt, Gemini 3.8 flash): audit tasks DHO-7 and LAD-2 (assigned to SEO Lead) each failed twice with `[Google AI Studio] Gemini models require OpenRouter reasoning details to be preserved ... Corrupted thought signature` (HTTP 400) on `gemini-3.8-flash`, after the first tool call. Cost of the four failed attempts: about $0.085 (OpenRouter `usage` 0.386 to 0.471; `byok_usage` unchanged at 0.199). Both tasks were cancelled so Paperclip would stop retrying. No reports were written, so step 6 (report check, cost, Monday routine) was not done.

**Fix: non-Gemini models (first tried DeepSeek and Qwen; now all Haiku 5.5, see below).** Hassan asked for better and cheaper models, so all four agents moved off Gemini: SEO Lead `openrouter/deepseek/deepseek-v4.1-flash` ($0.062 in / $0.144 out per million tokens, 1M context, served by Parasail), Writer `openrouter/qwen/qwen3.7-flash` ($0.03 / $0.13, served by Alibaba). `glm-5.3-flash` also passed a tool-call test. All three passed with the no-training filter on. Note for Ladva Law (client data): Qwen runs on Alibaba's endpoint; the Writer only sees facts in its task text, but check that this is acceptable before the Writer handles anything confidential.

**Re-run, tasks DHO-8 and LAD-3 (19 Oct).** Both finished in about 90 seconds and marked themselves done. Cost: OpenRouter `usage` rose from 0.4735 to 0.4873, so about $0.014 for both runs together (DHO-6 on Gemini 3.5 flash-lite cost $0.033, DHO-5 on 3.8-flash $0.39). `byok_usage` did not move (0.199), as expected for non-Google models. Reports: `reports/2026-10-19.md` in each workspace; data: `data/2026-10-19.json`.

**Report check against the data files.**
- Correct in both: PageSpeed, LCP, TBT, every ranking (organic and Maps), "not in top 30" wording, the per-page issue lists and title lengths, and the comparison with 18 Oct (54 to 56, LCP 4.1 s to 4.8 s, Maps 2 to 4 and 3 to 5). Dhobi's report correctly says two organic lookups failed ("Internal SE Server Error") instead of calling them unranked. Ladva's "first audit" is right.
- **Invented paths again, in both reports:** `/images/hero-steam.jpg` and `/js/main.js` (Dhobi), `/hero.webp` and `/main.js` (Ladva). The brief rule against inventing paths was not followed. Ladva's fix 4 also uses an example link (`/contact-us`) that is not in the data. Treat all code snippets as examples.
- **Unsupported claims.** Dhobi: "LocalBusiness is the strongest on-page signal for Maps". Ladva: fix 2 assumes the Google Business Profile is unclaimed, but "not found in Maps" only means the lookup didn't match the firm, so check Maps by hand first.
- **Data gap still not handled.** The on-page audit returned nothing for 15 of 20 pages on both sites. Dhobi's report says 13 were missing (it is 15) and Ladva's doesn't mention the gap at all, so every on-page finding rests on 5 pages. The workflow fix (one URL per request) is still open and is now the main quality problem.
- Dhobi's report missed that FAQPage schema is absent although the page has FAQ text, and suggests a meta description for the noindex thank-you page (pointless). Ladva's report ignored the `frame` issue on /contact-us and the 196-URL sitemap.
- Ladva's `llms.txt` first line ends in `\r` (Windows line ending). Dhobi's `# Dhobi &amp; Co` is still unconfirmed against the real file.

**Monday routine to set next:** one Paperclip routine per company, cron `0 9 * * 1` in Asia/Kolkata, that creates the task "Run the weekly audit as AGENTS.md describes." assigned to SEO Lead, with the working-directory line in the description. Heartbeat stays off. Expected cost per site per month: about $0.03 for four audits plus $0.16 for DataForSEO. Not created yet.

**Done after that (19 Oct, ~02:00 to 02:30 IST):**
- **n8n on-page gap fixed.** The workflow now has two new nodes, `Urls` (splits the URL list) and `Rejoin` (merges the answers), and `OnPage` sends one URL per request. Summary reads from `Rejoin`. Result: 20 of 20 pages audited on both sites (was 5), about 40 s per webhook call, about $0.043 DataForSEO per call. Live copy imported (backup `/root/n8n-backups/seo-data-2026-10-19-*-pre-onpage.json`), n8n restarted, repo file `n8n/seo-data-workflow.json` matches. Right after a restart the webhook answers 404 for a few seconds.
- **No-invented-paths rule** added to `agents/seo-lead.md`. The two rendered `AGENTS.md` files were copied straight into `/home/agent/work/dhobico` and `/home/agent/work/ladvalaw`; the server repo was left clean, so `git pull --ff-only` still works after the push.
- **Monday routines created** (Paperclip routines, one per company): title "Run the weekly audit as AGENTS.md describes.", assigned to SEO Lead, cron `0 9 * * 1`, timezone Asia/Kolkata, skip if a run is still active, missed runs skipped. Routine ids: Dhobi `7bf3f930-3a89-491b-a358-f771c94551a3`, Ladva `d027d3b0-9a8b-4848-9472-a2bffc47a09b`. The first fire is Monday 19 Oct 09:00 IST.

**Model comparison (same brief and same data, one call each, no tools).** Cost per report: qwen3.7-flash $0.0006, gpt-6-luna $0.001 to $0.0011, glm-5.3 $0.001, deepseek-v4.1-flash $0.0015 to $0.0047, claude-haiku-5.5 $0.0024 to $0.0029, glm-5.3-flash $0.0006 to $0.0039, qwen3.7-plus $0.006 to $0.008.
- **claude-haiku-5.5: best.** Specific fixes by page, placeholders instead of invented values, flagged that only 20 of 37 or 196 pages were audited, no invented paths. Weaknesses: put 2025 in a title (it has no date in the one-shot test; real runs use `date`) and sometimes quoted a fact that wasn't in its input.
- deepseek-v4.1-flash spent 6,300 reasoning tokens and was cut off mid-report. glm-5.3-flash returned an empty report once. gpt-6-luna is safe but gives generic, thin fixes. qwen3.7-flash invented details (WhatsApp, "600+ words"). qwen3.7-plus costs the most of the cheap ones for no gain. glm-5.3 gave short reports.
- Haiku also keeps client data on Anthropic's endpoint (OpenRouter showed "Claude Platform on AWS") instead of Alibaba, Wafer and other small hosts, which matters for the law firm.

**Current models: all four agents (both SEO Leads and both Writers) run `openrouter/anthropic/claude-haiku-5.5`** ($0.10 in / $0.50 out per million tokens). Real agent run on 19 Oct (new tasks for both sites, about 90 s each): OpenRouter `usage` rose 0.5761 to 0.5822, so about $0.006 for both runs together. Check of those reports against `data/2026-10-19.json`: all rankings, PageSpeed, LCP, TBT and the per-page issues are correct; no invented file paths or contact details (placeholders used). Wrong: page counts (Dhobi says 22 pages, Ladva says "10 audited URLs"; the data has 20 each), and Dhobi's last line says earlier pages "have no issues flagged today" (they are all in today's data). Still missing: FAQPage schema on Dhobi (FAQ text is present, FAQPage type is absent); the thank-you page is both noindexed and given a description.

Next: add a rule to `agents/seo-lead.md` to use `pagesAudited` for page counts, and mention missing FAQPage schema; confirm the Monday 09:00 routines fired and cost under $0.02 each; then the Writer hand-off test (SEO Lead asks the Writer for the 3 missing meta descriptions on ladvalaw.com).

## Next steps, in order

1. **Model comparison.** Re-run the audit on `gemini-3.8-flash` with the new brief and compare quality and cost with DHO-6. Pick one model. Rerun to confirm the previous-run fix.
2. **Fix the on-page audit gap** in the n8n workflow (15 of 20 pages failed), then re-export `n8n/seo-data-workflow.json` to the repo.
3. **Third test audit.** Create a task assigned to SEO Lead using the description below. Record steps, tokens and cost from the run log, and `byok_usage` before and after. Check every claim in the report against `data/<date>.json`.
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
- OpenSEO credit use: about 9,700 credits at the start; the first full day cost about 60 for two weekly runs plus one 50-page crawl. Watch `whoami` creditsRemaining. OpenRouter's key limit is $10 a month.
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
- n8n credential pitfalls: The hosted OpenSEO endpoint accepts only `x-api-key`, and a header Name with a space is rejected by n8n. A Query Auth credential's Name must be exactly `key`. A key without a Name sends requests anonymously and hits Google's shared quota.
- The `agent` user was first created with uid 1000, the same uid the n8n container runs as, which would have let agents stop n8n or read its files. It was recreated as uid 2000. Keep the two different.

## Start Claude Code on Hassan's desktop

Claude Code runs on the desktop, not the server, and reaches the server with `ssh root@txn-agn` over Tailscale. `CLAUDE.md` in the repo root has the exact commands and rules.

1. Make sure Tailscale is connected, then check SSH works (it may ask for a one-time browser approval):
   `ssh root@txn-agn hostname` should print `srv1305371`.
2. Get the repo: `git clone https://github.com/iamhsn/txn-agn && cd txn-agn`
3. Start Claude Code in that folder (`claude` in a terminal, or open the folder in the Claude desktop app's Code tab).

First message to Claude Code: "Read CLAUDE.md, docs/HANDOFF.md and docs/RUNBOOK.md, check the server over ssh, then tell me the current state in five lines and what you'd do first."

Optional: connect Claude Code to n8n's MCP server at `https://txn-agn.tailc354f1.ts.net/mcp-server/http` (works while Tailscale is on). Expose only the SEO workflows.
