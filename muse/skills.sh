# Per-skill settings shared by muse-skill (headless runner on the VM) and sync-data.sh (laptop <-> VM).
# Usage: . skills.sh; skill_config <skill>   -> sets DATA_FILES, ALLOWED, DENIED, EXTRA_CONTEXT

skill_config() {
  case "$1" in
    review-transactions)
      DATA_FILES="monarch-patterns.json state.json account-context.md categories-cache.json"
      ALLOWED="mcp__monarch-money"
      DENIED="mcp__monarch-money__delete_transaction,mcp__monarch-money__delete_account,mcp__monarch-money__delete_transaction_category,mcp__monarch-money__delete_transaction_rule,mcp__monarch-money__delete_transaction_tag,Bash"
      EXTRA_CONTEXT=""
      ;;
    cashflow-review)
      DATA_FILES="history.json insights.json"
      # Read-only Monarch tools, plus jq (read/filter only) for oversized get_cashflow results.
      ALLOWED="mcp__monarch-money__get_cashflow,mcp__monarch-money__get_cashflow_summary,mcp__monarch-money__get_budgets,mcp__monarch-money__get_transactions,mcp__monarch-money__get_transaction_categories,mcp__monarch-money__get_transaction_category_groups,mcp__monarch-money__get_recurring_transactions,mcp__monarch-money__get_accounts,Bash(jq:*)"
      DENIED="mcp__monarch-money__set_budget_amount"
      EXTRA_CONTEXT="The only shell command you may run is jq (read/filter). When get_cashflow output is too large and gets saved to a file, process that file with jq. Monarch is read-only in this run: don't change budgets or transactions."
      ;;
    *) echo "unknown skill: $1" >&2; return 1 ;;
  esac
}
