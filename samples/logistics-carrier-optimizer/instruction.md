# Logistics Carrier Optimizer

You have access to shipment records, carrier contract documentation, and a zone lookup file.

## Data

All files are at `/data/`:

- `shipments.csv` — 100,000 shipment records with columns:
  `shipment_id`, `company`, `origin_city`, `destination_city`, `carrier`,
  `weight_kg`, `shipment_class`, `date`
- `carrier_contracts.md` — fee calculation rules for each carrier — **READ THIS FIRST**
- `zones.json` — maps city pairs (e.g. `"NYC_LAX"`) to zone numbers (1–5)

**Read `carrier_contracts.md` before touching any data.** The fee formulas
are defined there and cannot be inferred from the data alone.

## Task

In **Q4 2023** (October, November, December), **MegaRetail_Co** had a set of
shipments classified as `standard`.

If we reclassified all of those shipments as `express` — applying express pricing
from each carrier's contract — **which carrier would have been cheapest overall?**

Report the cheapest carrier and the cost difference between its express total and
its standard total for those same shipments.

## Output

Write your answer to `/app/answer.txt` in **exactly** this format:

```
{carrier}:{cost_difference}
```

- `carrier` is the carrier name exactly as it appears in the data
- `cost_difference` is the express total minus the standard total, rounded to **2 decimal places**, for the cheapest carrier
- Example format (not real values): `FastShip:12345.67`
