# claude-skills

Personal Claude Code skills. Invoke any skill with `/skill-name` in a Claude Code session.

## Skills

### `/review-transactions`
Reviews Monarch Money transactions flagged for review (`needs_review: true`). Uses a local pattern knowledge base to suggest categories instantly — only falls back to fetching transaction history for unknowns. Learns from every confirmed run.

**Flow:** Fetch needs-review → match against saved patterns → fetch history for unknowns → show suggestion table → wait for confirmation → apply + update patterns.

**Files:**
- `review-transactions/SKILL.md` — skill definition
- `review-transactions/monarch-patterns.json` — learned categorization patterns (grows over time, gitignored)
- `review-transactions/categories-cache.json` — Monarch category list (cached permanently, gitignored; delete to refresh)

> **Dependency note:** This skill uses `needs_review: true` filtering in `get_transactions`, which requires a patched version of the Monarch Money MCP server. The upstream PR is at [bradleyseanf/monarchmoneycommunity#20](https://github.com/bradleyseanf/monarchmoneycommunity/pull/20). Until merged, apply the patch locally or the skill will return no transactions.

---

### `/compare-portfolio`
Compares US portfolio holdings between a Google Sheet (source of truth) and SavvyTrader. Flags missing tickers and quantity drift above 0.1 shares.

**Flow:** Read sheet via `gws` + fetch SavvyTrader holdings in parallel → diff tickers and quantities → clean one-liner output when in sync, detailed table when issues found.

**Requirements:**
- [`gws`](https://github.com/tanaikech/gws) CLI — a Google Workspace CLI; authenticate with `https://www.googleapis.com/auth/spreadsheets` scope
- `savvytrader` MCP server configured ([harshitbshah/savvytrader-client](https://github.com/harshitbshah/savvytrader-client))
- Update the Sheet ID and portfolio IDs in `compare-portfolio/SKILL.md` with your own values

---

## Setup

### Clone

```bash
git clone https://github.com/harshitbshah/claude-skills.git ~/.claude/skills
```

### Configure `/compare-portfolio`

Set these env vars in your shell. The recommended approach is a [private dotfiles repo](https://github.com/harshitbshah/dotfiles) sourced by `~/.bashrc`:

```bash
export PORTFOLIO_SHEET_ID="your-google-sheet-id"
export SAVVY_MAIN_PORTFOLIO_ID="your-main-portfolio-id"
export SAVVY_ETF_PORTFOLIO_ID="your-etf-portfolio-id"
```

Find your Sheet ID in the URL: `docs.google.com/spreadsheets/d/<ID>/`  
Find your SavvyTrader portfolio IDs by calling `mcp__savvytrader__get_my_portfolios` in a Claude Code session.

### Configure `/review-transactions`

No config needed. On first run it creates `monarch-patterns.json` automatically. The file is gitignored so your personal patterns stay local.

---

## Keeping skills backed up

After updating a skill or after `monarch-patterns.json` has grown meaningfully:

```bash
cd ~/.claude/skills && git add . && git commit -m "update patterns" && git push
```
