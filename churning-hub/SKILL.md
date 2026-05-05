---
name: churning-hub
description: Manage the Churning Hub Excel tracker (Doctor of Credit template) — add/edit/clean credit cards, bank bonuses, points, and credit scores. File at ~/gdrive/Important Documents/Churning Hub.xlsx
---

# churning-hub

Manage the Churning Hub credit card and bank bonus tracker.

**File:** `~/gdrive/Important Documents/Churning Hub.xlsx`
**Library:** Use `openpyxl` (available). Do NOT use pandas — preserve formulas.

---

## Critical rules

- **Never overwrite row 2** on any sheet — it contains summary formulas.
- **Never overwrite formula cells** (cols E–J, L, O on Credit Cards). Only write to data columns.
- When cleaning sample data, delete row values but preserve the row structure and formulas.
- Use `openpyxl.load_workbook(..., keep_vba=False)` — no macros in this file.
- After any write, save back to the same path.

---

## Sheet structure (quick ref)

### Credit Cards — data starts row 4 (row 3 = first sample row to clean)
Write-able columns per card entry:
- **A**: Bank name
- **B**: Card name (include "Business" if applicable — affects utilization formula)
- **C**: Type (V/M/A/D)
- **D**: Credit limit
- **K**: Closing date day-of-month (integer)
- **M**: Current balance
- **N**: Due date day-of-month (integer)
- **P**: Statement balance
- **Q**: Payment scheduled
- **R**: Promo APR start date
- **S**: APR (0 if promo/no interest)
- **T**: Promo APR end date
- **U**: Annual fee ($)
- **V**: Annual fee post date
- **W**: Bonus description (e.g. "60k UR", 200.0)
- **X**: Min spend met? (Y / N / N/A)
- **Y**: Min spend required ($)
- **Z**: Amount spent toward min spend ($)
- **AA**: Date opened
- **AB**: Date bonus received (or N/A)
- **AC**: Date closed (or N/A)
- **AD**: Date of last charge

Do NOT write to cols E–J (utilization thresholds/calc) or L, O (display formulas).

### Better Bonus Tracking — group structure
Each currency block:
- Row N: group header (formula in col B, card names in cols D+)
- Rows N+1 to N+7: categories (Signup, Travel, Dining, Rotating Category, Base, Referral, Shop)
- Row N+8: Used (negative value)
To add points: write value into the matching card column + category row.

### Bank Bonuses — data starts row 3
Write-able per entry:
- A: Bank, B: Account, C: APY
- D: Pending balance, E: Current balance (F=D+E formula, don't touch)
- G: Applied date, H: Approved date, I: Closed date
- J: Bonus $, K: Bonus received date, L: Bonus met (Y/N)
- M: DD amount required, N: DD done
- O: Monthly fee $
- P–V: Monthly fee-free status (Y = met, X = not met, blank = N/A)

### Credit Score — data starts row 4
- A + B: Date (1st of month) + Chase/Experian FICO 8
- C + D: Date (15th of month) + BofA/TransUnion FICO 8
- E + F: Date (28th of month) + Amex/Experian FICO 8

---

## Common tasks

### Clean sample data
Sample rows in Credit Cards: rows 3–~15 (Amex BCP, Platinum, PRG, BofA cards, Chase cards)
Sample rows in Bank Bonuses: rows 3–8 (Schwab, Chase, HSBC, PNC, Santander, WF)
Sample rows in Credit Score: rows 4+ with scores like 9001, 8999... (fake)

To clean: iterate rows, check if values look like sample data (round fake numbers, known sample banks), then clear cell values while keeping formulas intact.

### Add a credit card
Find first empty row (col A is None) starting from row 4. Write all data columns. Do not touch formula columns.

### Add a bank bonus
Find first empty row in Bank Bonuses starting from row 3. Write data. Leave col F (Total) alone — it has a formula.

### Add credit score entry
Find first empty row in Credit Score starting from row 4. Write date + score in appropriate columns.

---

## Loading the workbook

```python
import openpyxl
from datetime import datetime

wb = openpyxl.load_workbook('/home/harshit-shah/gdrive/Important Documents/Churning Hub.xlsx')
cc = wb['Credit Cards']
bb = wb['Better Bonus Tracking']
bank = wb['Bank Bonuses']
score = wb['Credit Score']
# ... make changes ...
wb.save('/home/harshit-shah/gdrive/Important Documents/Churning Hub.xlsx')
```
