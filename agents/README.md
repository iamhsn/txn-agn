# Agent briefs

Each site gets a workspace on the server at `/home/agent/work/<site>/`. Copy these files there:

| File | Goes to | Used by |
|---|---|---|
| `seo-lead.md` | `AGENTS.md` (replace `{{SITE}}`, `{{BRAND}}`, `{{MARKET}}`) | SEO Lead |
| `writer.md` | `writer/AGENTS.md` | Writer (working directory `/home/agent/work/<site>/writer`) |

## Models and budgets

| Agent | Model | Why | Paperclip budget |
|---|---|---|---|
| SEO Lead | `openrouter/google/gemini-3.8-flash` | Reads data and ranks fixes. Needs reasoning; the weekly audit runs once | $2 / month |
| Writer | `openrouter/google/gemini-3.8-flash-lite` | Short drafts from a clear brief. Switch to flash only if drafts fail review twice | $1 / month |
| Company total | | | $3 / month per site |

Six sites at $3 each is $18 a month at most, so raise the OpenRouter key limit from $10 to $20 before onboarding all five clients.

## Keeping a run cheap

DHO-5 cost $0.39 because the agent read the full data file and took many steps. The rules in `seo-lead.md` target about $0.10:

1. The `jq` filter cuts the data to what the report needs before the model sees it.
2. One command to fetch, one file to write, one comment. No crawling, no re-reading files.
3. Weekly routine only (Mondays 09:00 Asia/Kolkata). Heartbeat off.
4. Max one concurrent run per agent.
5. The Writer only runs when SEO Lead assigns it a task, and gets the facts in the task text, so it never fetches data.

Check spend after each run in OpenRouter → Activity. If a run passes $0.20, look at its step count in Paperclip first.
