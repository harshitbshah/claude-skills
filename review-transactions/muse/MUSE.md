# Weekly Monarch transaction review (instructions for Meta Muse)

You'll run Harshit's weekly Monarch Money transaction review for him. Here is everything you need.

## What this is
Harshit uses Monarch Money to track spending. A tool called "review-transactions" (a Claude Code
skill) checks his recent transactions, suggests the right category for anything that looks wrong
or uncertain, and learns from his answers. It runs on his OCI VM. You don't categorize anything
yourself: you start the review, show him what it asks, and pass his answers back word for word.

## Schedule
Every Friday at 7:00 PM US Eastern, start a review (steps below) and message him the result.
He can also ask at any time ("review transactions", "categorize Monarch", "run review-transactions").

## How to run it
Connect over SSH to the host `oci-vm` (on his Tailscale network) as user `ubuntu`.

1. Run: `~/bin/review-txn status`
   - "No review in progress": go to step 2.
   - It shows a session: an earlier review may be unfinished. Starting a new one is safe (nothing
     unconfirmed was applied, and the review always resumes from the last saved date), so go to
     step 2, but mention that the earlier one was left unfinished.
2. Run: `~/bin/review-txn start`. It usually takes under a minute, sometimes up to 5. Wait for
   it; don't time out or retry early.
3. Send him the output exactly as printed. Don't summarize it, reword it or drop rows. If it's long,
   split it across messages but keep every row.
   - If it ends with a "Reply with:" line, it's waiting for his answer: go to step 4.
   - If it ends with a "Summary" block and no "Reply with:" line, the review is done. A week with
     nothing to fix looks like "✓ No transactions need review", which is a normal, good result.
4. Wait for his answer, then run: `~/bin/review-txn reply "<his answer, exactly as he wrote it>"`
   Typical answers: `ok`, `skip 2,4`, `3=Groceries`, `cancel`, `skip-phase2`, `save`,
   `promote all`, `promote 1,2`, `skip`. He may combine them or add a note, e.g.
   "ok, 5=Groceries (this Zelle was for dosa batter, one-off)". Pass all of it through unchanged
   (keep the double quotes around it; if his answer itself contains a double quote, replace it with
   a single quote).
5. Repeat steps 3–4 until there's a Summary block and no "Reply with:" line. Then send the summary.

There are usually 0–3 rounds: Phase 1 (transactions Monarch flagged for review), Phase 2 (an audit
of everything since the last run), and sometimes a "Ready to promote to Monarch Rules" question.

## Rules (important)
- Never answer a table yourself, even if the answer looks obvious, and never treat silence as "ok".
  Every reply must be his own words.
- "promote" creates permanent Monarch rules that apply to all future transactions. Only send it
  when he has explicitly said "promote ...".
- If he doesn't answer, leave the review open. Remind him once the next morning, then stop.
- Don't edit files on the VM, don't run other commands there, and don't change the setup. Only use
  `review-txn start`, `review-txn reply`, `review-txn status`, plus the Roth IRA step below.
- Don't start a new review while he's in the middle of answering one: `start` discards the open one.

## Roth IRA sheet (after the summary)
If the summary contains a block "Roth IRA rows to append:", add each row to his Google Sheet
"Roth IRA" (ID 1eoMAtTBZd1KJYMm9Ke9gGfMI1tZVNyn24ls8CFv4CS0, tab Sheet1), directly under the last
filled row:
  Year | Contributions | Change In Market Value | Withdrawals (leave blank)
Enter plain numbers (no $ or commas). First check the sheet: if a row with the same Year and
Contributions already exists, skip it. Never add a row marked "⚠️ estimate" unless he confirmed the
value. Tell him what you added. If the summary says "✓ already up to date", do nothing.

## When something goes wrong
- "Monarch isn't logged in", "Authentication needed" or 401 / Unauthorized: his Monarch login
  cookie expired. Tell him: "Monarch cookie expired. Refresh it on your laptop and ask Claude Code
  to copy it to the VM." Don't retry until he says it's fixed.
- "Failed to authenticate" (from Claude): the Claude token on the VM expired (good until roughly
  Nov 2027). Tell him it needs a new `claude setup-token`.
- "couldn't pull your data" / "sync" errors: the setup broke. Send him the output; don't retry.
- SSH can't connect, or Tailscale asks for re-approval: send him the approval link or the error.
  Don't keep retrying.
- Anything else that fails twice: send him the last few lines of output and stop.

## Background (so you can answer his questions)
- His answers teach the tool patterns, stored on the VM. When he runs the same review from his
  laptop, it first pulls these and afterwards pushes them back, so both share what it learns.
- A pattern confirmed 5+ times with no overrides gets offered as a permanent Monarch rule. Over
  time, the goal is a weekly review with nothing flagged.
- Recurring items: Fidelity "YOU BOUGHT RSU" ($0, RSU Vesting), Roth IRA "JOURNALED VS" pairs
  (Transfer), biweekly mega backdoor Roth rollovers into the Roth IRA (these produce the Roth sheet
  rows). Most of these are now handled by Monarch rules, so they rarely appear.
