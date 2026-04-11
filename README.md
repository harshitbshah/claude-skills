# claude-skills

A collection of personal [Claude Code](https://claude.ai/code) skills for automating financial workflows — portfolio reconciliation, transaction categorization, and more.

## What are Claude Code skills?

Claude Code skills are reusable prompt definitions that Claude Code loads and executes when you type `/skill-name` in a session. Each skill lives in its own directory as a `SKILL.md` file that tells Claude exactly what to do — which APIs to call, how to process the data, and what to output.

Skills can call MCP servers, run shell commands, read/write local files, and chain multiple steps together. They're the difference between typing a long prompt every time and just typing `/compare-portfolio`.

---

## Skills

### `/compare-portfolio`

Diffs your US portfolio between a Google Sheet (source of truth, updated daily by [portfolio-sync](https://github.com/harshitbshah/portfolio-sync)) and SavvyTrader (model portfolio). Surfaces missing positions and quantity drift above 0.1 shares in seconds.

**Before:** 20 minutes of manual tab-switching across Monarch, SavvyTrader, and a spreadsheet every week.  
**After:** One command.

**Example output:**

```
=== US Portfolio Comparison ===
Sheet: 28 tickers | SavvyTrader: 27 tickers (portfolios merged)

❌ ONLY IN SHEET (not in SavvyTrader):
  PGY — 757.68 shares  (position may be closed in brokerage but not removed from model)

✅ All other tickers present in both
✅ All quantities in sync: 27 of 27 shared tickers within 0.1 share tolerance

Last synced: 2026-04-10 14:02 UTC
```

**How it works:**
1. Reads holdings from Google Sheet via `gws` CLI
2. Fetches all SavvyTrader portfolios via the [savvytrader-client](https://github.com/harshitbshah/savvytrader-client) MCP server — in parallel
3. Merges and diffs: missing tickers, extra tickers, quantity mismatches above tolerance
4. Reports clean one-liners when in sync, detailed table when issues found

**Requirements:**
- [`gws`](https://github.com/tanaikech/gws) CLI authenticated with `https://www.googleapis.com/auth/spreadsheets` scope
- `savvytrader` MCP server ([harshitbshah/savvytrader-client](https://github.com/harshitbshah/savvytrader-client))
- Env vars configured (see Setup below)

---

### `/review-transactions`

Reviews Monarch Money transactions flagged for review (`needs_review: true`). Uses a local pattern knowledge base to suggest categories instantly — only falls back to fetching transaction history for unknowns. Learns from every confirmed run, so it gets faster over time.

**How it works:**
1. Fetches all `needs_review` transactions from Monarch Money
2. Matches each against saved patterns (`monarch-patterns.json`) — confident matches skip the API entirely
3. For unknowns, fetches the last 30 transactions from the same merchant to infer category
4. Presents a review table — you confirm, skip, or override individual rows
5. Applies updates to Monarch and writes new patterns back to the local file

**Example output:**

```
| # | Date       | Account  | Description        | Amount  | Suggested Category       | Source                  |
|---|------------|----------|--------------------|---------|--------------------------|-------------------------|
| 1 | 2026-04-08 | Chase    | WHOLEFDS MKT #1234 | -$87.32 | Groceries                | 📚 confident (seen 12×) |
| 2 | 2026-04-09 | Fidelity | Transferred From   | -$500   | Retirement Contributions | 📖 learning (seen 2×)   |
| 3 | 2026-04-10 | Chase    | OPENAI *CHATGPT    | -$20.00 | GenAI                    | 📊 from history         |

Reply with: ok / skip 2, 4 / 3=Medical / cancel
```

**Files:**
- `review-transactions/SKILL.md` — skill definition
- `review-transactions/monarch-patterns.json` — learned patterns (grows over time, gitignored)
- `review-transactions/categories-cache.json` — Monarch category list (cached permanently, gitignored; delete to refresh)

**Requirements:**
- [Monarch Money MCP server](https://github.com/monarch-money/monarch-money) — v0.x or later (requires `needs_review` filter support, merged in [bradleyseanf/monarchmoneycommunity#20](https://github.com/bradleyseanf/monarchmoneycommunity/pull/20))

---

## Setup

### 1. Clone

```bash
git clone https://github.com/harshitbshah/claude-skills.git ~/.claude/skills
```

Claude Code automatically picks up skills from `~/.claude/skills/` — no further registration needed.

### 2. Configure `/compare-portfolio`

Set these env vars in your shell. The recommended approach is a private dotfiles repo sourced by `~/.bashrc`:

```bash
export PORTFOLIO_SHEET_ID="your-google-sheet-id"
export SAVVY_MAIN_PORTFOLIO_ID="your-main-portfolio-id"
export SAVVY_ETF_PORTFOLIO_ID="your-etf-portfolio-id"
```

Find your Sheet ID in the URL: `docs.google.com/spreadsheets/d/<ID>/`  
Find your SavvyTrader portfolio IDs by calling `mcp__savvytrader__get_my_portfolios` in a Claude Code session.

### 3. Configure `/review-transactions`

No config needed. On first run it creates `monarch-patterns.json` automatically. The file is gitignored so your personal patterns stay local.

---

## Adding your own skill

1. Create a new directory: `mkdir ~/.claude/skills/my-skill`
2. Add a `SKILL.md` with a YAML frontmatter block and a description of what Claude should do:

```markdown
---
name: my-skill
description: One-line description shown in Claude Code's skill picker
---

# my-skill

Tell Claude exactly what to do here — which tools to call, in what order,
how to handle errors, and what to output.
```

3. Invoke it in any Claude Code session with `/my-skill`

Skills have access to everything Claude Code does — MCP servers, Bash, file read/write, web fetch. The `SKILL.md` is just a structured prompt that gets injected when you invoke the skill.

---

## Keeping skills backed up

After updating a skill or after `monarch-patterns.json` has grown meaningfully:

```bash
cd ~/.claude/skills && git add . && git commit -m "update patterns" && git push
```
