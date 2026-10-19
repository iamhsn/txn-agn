# Plan: OpenSEO as the data source (Option B)

Status: draft for Hassan's review. Nothing here is deployed yet.

## The decision

Hosted OpenSEO (the $10 plan plus usage, about $16.55 a month for 10 sites) replaces direct DataForSEO calls as the source of all SEO data. n8n pulls from OpenSEO, and the agents work from that data.

We use the hosted plan, not a self-hosted copy. Self-hosted OpenSEO uses our own DataForSEO key, which puts back the two $100-a-month minimums (backlinks and LLM mentions) that we're avoiding.

## How it fits the current setup

```
Before:  n8n --DataForSEO--> /webhook/seo-data --> SEO Lead --> Writer
After:   n8n --OpenSEO API--> /webhook/seo-data --> SEO Lead --> Writer --> Developer
         n8n --PageSpeed + on-page checks (kept)--^
```

- **n8n "SEO data (agents)" workflow.** The rankings, Maps and keyword research calls switch from DataForSEO to OpenSEO's REST API. New calls are added for backlinks and AI prompt checks. The webhook URL and its JSON shape stay the same, plus new `backlinks`, `aiMentions` and `keywordIdeas` fields. The agents' fetch command doesn't change.
- **PageSpeed and on-page checks.** These stay as they are, since they're free or cheap and already work. The DataForSEO OnPage call is replaced only if OpenSEO's site audit covers the same checks.
- **SEO Lead brief.** Two report sections are added: "Backlinks (new and lost this week)" and "AI answers (which prompts mention us)". The jq filter is extended to trim the new fields.
- **Developer agent (new).** It applies approved fixes and publishes posts through the WordPress MCP. It writes as a draft or on staging only, and Hassan approves each change before it goes live. It runs on flash.
- **Writer.** Runs on a free model, with flash-lite as the fallback.
- **Reviewer.** Not a separate agent. A script checks lengths, banned claims and JSON-LD validity, and SEO Lead checks the facts.
- **Researcher.** Not a separate agent. n8n runs keyword research through OpenSEO once a month, and SEO Lead picks the topics.
- **Secrets.** The OpenSEO token goes in the n8n credentials store, never in the repo.

## What improves

- **Backlinks.** We get our own and competitors' backlink profiles, with new and lost links. We have no backlink data today.
- **AI prompt tracking.** We see whether ChatGPT, Gemini and others mention the brand for target prompts. This is the core of the AEO work, and we have none of it today.
- **Keyword research.** About 20 searches per site per month, giving search volume and difficulty. Today the keywords are picked by hand in the Config node.
- **More keywords tracked.** Rank tracking grows from 5 to 20 keywords per site, weekly, for both organic and Maps.
- **One dashboard.** Hassan can open OpenSEO to check numbers without going through an agent.
- **Predictable cost.** OpenSEO is one bill with a calculator, instead of per-call DataForSEO charges.

## What we lose or risk

- **Cost goes up.** Data rises from about $1.60 to about $16.55 a month. With agents, the total goes from about $7–9 to about $25 for 10 sites.
- **Dependence on OpenSEO.** If OpenSEO changes its prices or API, or shuts down, the data stops. The fallback is DataForSEO pay-as-you-go for rankings, Maps and keywords; we'd lose backlinks and AI data.
- **Less control over raw data.** Today n8n picks the exact DataForSEO parameters (location, depth, device). With OpenSEO, we get whatever its settings give us.
- **Extra work to connect it.** OpenSEO's REST and MCP tool list needs checking before the build: auth tokens, rate limits and which endpoints cover local SERP and AI prompts.
- **Another account holding client data.** The site list and keywords for Ladva and other clients now sit with a third party.

## Monthly cost, 10 sites

| Item | Now | After |
|---|---|---|
| SEO data | about $1.60 (DataForSEO) | about $16.55 (OpenSEO) |
| SEO Lead audits | about $4.00 | about $4.50 (larger report) |
| Writer | about $1.00 | $0–1.00 (free model first) |
| Developer | not set up yet | about $1–2 |
| **Total** | **about $7** | **about $22–24** |

The hard stop in Paperclip stays at $1 per site per month for agent spend; OpenSEO bills separately. Leftover DataForSEO balance stays available as a fallback.

## Steps

1. Hassan signs up for OpenSEO (Freelancer/agency, 10 sites) and creates an API token. *Only Hassan can do this, because it's account and payment setup.*
2. Check OpenSEO's API: list its MCP and REST tools and confirm endpoints for rank tracking, local SERP, backlinks, keyword research and AI prompts. Note the rate limits.
3. Add both sites in OpenSEO with 20 keywords each and the AI prompts to track. Draft lists:
   - Dhobi & Co: "ironing service Hyderabad", "doorstep ironing near me" and similar.
   - Ladva: the 5 existing keywords plus 15 from keyword research.
4. Update the n8n workflow: OpenSEO calls, the new fields, a backup export before importing, and a test call for each site.
5. Update `seo-lead.md` (new sections and jq filter). Add `developer.md` and `scripts/check-copy.sh` (the Reviewer script).
6. Create the Writer and Developer agents in Paperclip for both organisations, with budgets.
7. Run a test audit for each site, check the reports against the data, and record the cost.
8. Set up the weekly routine: Mondays 09:00 Asia/Kolkata.

## Open questions

- Does OpenSEO's AI prompt tracking cover Perplexity and Google AI Overviews, or only ChatGPT?
- Can the OpenSEO token be limited to read-only access?
