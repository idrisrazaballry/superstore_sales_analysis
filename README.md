# Superstore Sales Analysis (SQL)

Analysis of ~10,000 retail order line-items using SQLite, covering profitability,
returns, discounting, and regional performance.

**Stack:** SQLite · SQL (joins, window functions, CTEs) · Python (loading)

---

## Setup

```bash
git clone https://github.com/⟨handle⟩/superstore-sql-analysis
cd superstore-sql-analysis
python load.py            # builds superstore.db from data/*.csv
sqlite3 superstore.db < queries/analysis.sql
```

---

## The data

Three tables:

| Table | Rows | Description |
|---|---|---|
| `orders` | ⟨N⟩ | One row per product line within an order |
| `returns` | ⟨N⟩ | Order IDs that were returned |
| `managers` | 4 | Regional manager assignment |

`orders.order_id` → `returns.order_id` (one-to-many; most orders never return)
`orders.region` → `managers.region`

---

## Questions and findings

> Replace each ⟨...⟩ with what your query actually returned. This section is
> what a reviewer reads first — the SQL is the evidence, the finding is the point.

**1. Which categories drive revenue vs. profit?**
⟨e.g. Tables generated $X in revenue but lost $Y — the only sub-category with
negative total profit, despite being third by volume.⟩

**2. Top 3 sub-categories per region**
⟨What differs between regions? Does one region's mix look unlike the others?⟩

**3. Month-over-month growth**
⟨Is there seasonality? Which months repeat as peaks across years?⟩

**4. Return rates by category**
⟨Which category is returned most, and is the gap large enough to act on?⟩

**5. Does discounting work?**
⟨At what discount band does margin go negative? That threshold is the finding.⟩

**6. Customer concentration**
⟨What share of revenue do the top 10 customers hold? Concentration risk?⟩

**7. Cumulative revenue trajectory**
⟨Steady growth, or is one year carrying the total?⟩

**8. Loss-making sub-categories by manager**
⟨Does one region account for most of the losses, or is it spread evenly?⟩

---

## What I'd do next

⟨Two or three sentences. E.g. the discount analysis is correlational — a proper
test would need controlled pricing. Returns data has no reason codes, so the
return-rate finding says where but not why.⟩

Naming the limits of your own analysis is worth more than another query.
