# Agent briefs

Each site gets a workspace on the server at `/home/agent/work/<site>/`. Copy these files there:

| File | Goes to | Used by |
|---|---|---|
| `seo-lead.md` | `AGENTS.md` (replace `{{SITE}}`, `{{BRAND}}`, `{{MARKET}}`) | SEO Lead |
| `writer.md` | `writer/AGENTS.md` | Writer (working directory `/home/agent/work/<site>/writer`) |

## Models and budgets

| Agent | Model | Why | Paperclip budget |
|---|---|---|---|
| SEO Lead | `openrouter/google/gemini-3.8-flash` | Reads data and ranks fixes. The weekly audit runs once | $0.75 / month |
| Writer | `openrouter/google/gemini-3.8-flash-lite` | Short drafts from a clear brief. Switch to flash only if drafts fail review twice | $0.25 / month |
| Company total | | | $1 / month per site (hard stop) |

Expected spend per site per month: DataForSEO data $0.16 (4 runs at $0.04), audits $0.40 (4 at about $0.10), Writer drafts about $0.10. That's about $0.65, or $6.50 for 10 sites. The $10 OpenRouter limit covers 10 sites. If an audit can't get under $0.10, move the fix ranking into n8n code and let the model only write the report.

## Keeping a run cheap

DHO-5 cost $0.39 because the agent read the full data file and took many steps. The rules in `seo-lead.md` target about $0.10:

1. The `jq` filter cuts the data to what the report needs before the model sees it.
2. One command to fetch, one file to write, one comment. No crawling, no re-reading files.
3. Weekly routine only (Mondays 09:00 Asia/Kolkata). Heartbeat off.
4. Max one concurrent run per agent.
5. The Writer only runs when SEO Lead assigns it a task, and gets the facts in the task text, so it never fetches data.

Check spend after each run in OpenRouter → Activity. If a run passes $0.20, look at its step count in Paperclip first.
