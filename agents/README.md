# Agent briefs

Each site gets a workspace on the server at `/home/agent/work/<site>/`. Render it with:

```
/opt/txn-agn/scripts/site-workspace.sh <site> "<brand>" "<market>" [<wordpress base url>]
```

| Brief | Goes to | Agent |
|---|---|---|
| `seo-lead.md` | `AGENTS.md` | SEO Lead (the Paperclip CEO) |
| `writer.md` | `writer/AGENTS.md` | Writer |
| `developer.md` | `developer/AGENTS.md` | Developer |
| `../scripts/check-copy.sh` | `bin/check-copy.sh` | The Reviewer: SEO Lead runs it on every Writer draft |

## Team, models and budgets (per site, since 19 Oct 2026)

| Agent | Model | Budget / month | Job |
|---|---|---|---|
| SEO Lead | `openrouter/anthropic/claude-haiku-5.5` | $0.75 | Reads the webhook data, writes the report, creates Writer and Developer tasks |
| Writer | `openrouter/google/gemini-3.5-flash-lite` | $0.25 | Drafts titles, meta descriptions, FAQ, schema, posts from facts in the task |
| Developer | `openrouter/anthropic/claude-haiku-5.5` | $0.50 | Creates WordPress drafts through the REST API; never publishes or deletes |
| Company hard stop | | $1.50 | |

All agents: heartbeat off, 1 concurrent run, no permission to create other agents. Companies: "Dhobi & Co." (DHO), "ACRE Realty" (ACR) and "ACG United" (ACG). "Ladva Law Firm" (LAD) was paused on 22 Oct 2026 and is being removed.

Why these models: Gemini 3.8 flash failed twice with "corrupted thought signature" on 19 Oct and costs about 8 times more per token than Haiku 5.5 ($0.825 / $4.125 against $0.10 / $0.50 per million). The free `google/gemma-4-26b-a4b-it:free` made a good tool call in a direct test, but as a Writer it stalled for over five minutes. `gemini-3.8-flash-lite` does not exist; 3.5 flash-lite is the cheap Google option.

## Flow

1. n8n collects the data (webhook `seo-data`): OpenSEO audit, rank tracker, Maps, AI answers and backlinks, plus PageSpeed. Each call saves a row in `seo_snapshots`.
2. SEO Lead runs the audit, writes `reports/<date>.md`, and for any fix that needs copy creates a **Writer** task with the facts.
3. Writer drafts as `TITLE:` / `META:` / ```json lines.
4. SEO Lead saves it to `drafts/` and runs `bin/check-copy.sh <file> --site <site>` (lengths, JSON-LD, placeholders, law-firm wording, and warnings for words like "free" and "best"), then checks each claim against the facts.
5. Only a passing draft goes to a **Developer** task. The Developer makes a WordPress draft (new content) or an autosave (existing content) and sets the task to `in_review`. Hassan publishes.

Developer needs `WP_<SITEKEY>_USER` and `WP_<SITEKEY>_APP_PASSWORD` (for example `WP_DHOBICO_USER`) in `/home/agent/.config/paperclip.env`, then a Paperclip restart. Without them it blocks the task with "needs WP credentials". Never put these in the repo.

## Routines (Paperclip, Asia/Kolkata)

| When | Task |
|---|---|
| Mondays 06:00 | OpenSEO re-checks the 10 tracked keywords per site (OpenSEO's own weekly schedule) |
| Mondays 07:00 | n8n "SEO monthly pull" calls the webhook for both sites, but only acts on the first Monday: starts the site audit, refreshes backlinks, saves a snapshot |
| Mondays 09:00 | SEO Lead: "Run the weekly audit as AGENTS.md describes." |
| Mondays 10:00 | SEO Lead: "Monthly: …". Acts only on the first Monday: audit, up to 2 page or post proposals, delegates to the Writer. Other Mondays it marks the task done at once |

## Keeping a run cheap

Measured on 19 Oct: a weekly audit costs about $0.010 per site, a blocked Developer run $0.011, a Writer draft under $0.005. Rules that keep it there: the `jq` filter trims the data before the model sees it; one command to fetch (with `timeout: 300000`, because the webhook takes 80 to 115 s and OpenCode's default tool timeout is 120 s), one file to write, one comment; no skills (the core `paperclip` skill still loads unless the brief says not to); heartbeat off. If a fetch fails, the agent blocks the task instead of using an older data file.
