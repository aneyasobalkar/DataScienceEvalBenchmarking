# QRA: Logistics Carrier Optimizer — MegaRetail_Co Q4 2023 Express Reclassification

## Question

In Q4 2023, which carrier would have been cheapest for MegaRetail_Co's shipments if we reclassified all their `standard` shipments to `express`? Report the carrier name and the cost difference rounded to 2 decimal places.

## Reasoning

### Step 1 — Parse carrier_contracts.md

Four carriers, each with distinct rules. The critical subtlety: **weight breaks must be applied to the per-kg rate BEFORE the express multiplier** for three of the four carriers. Applying them in the wrong order changes the answer.

**FastShip**
- per_kg = zone × 2.50
- if weight > 20 kg: per_kg × 0.85 (15% discount)
- standard fee = per_kg × weight
- express fee = per_kg × weight × 1.8
- No flat surcharges

**ReliableExpress**
- per_kg = zone × 3.00
- if weight > 15 kg: per_kg × 0.90 (10% discount)
- standard fee = per_kg × weight
- express fee = (per_kg × weight × 1.5) + 2.50 flat per shipment
- Fuel surcharge 2.50 EUR for express ONLY

**BudgetFreight**
- per_kg = zone × 2.00 (no weight breaks)
- standard fee = zone × 2.00 × weight × 1.015 (1.5% handling always)
- express fee = zone × 2.00 × weight × 2.2 × 1.015
- Handling fee applies to ALL shipments — easy to miss or misapply

**PrimeLogistics**
- per_kg = zone × 2.75
- if weight > 25 kg: per_kg × 0.80 (20% discount)
- standard fee = per_kg × weight
- express fee = per_kg × weight × 1.6 + (5.00 if zone ≥ 4 else 0)
- Zone premium 5.00 EUR for express in zones 4–5 only

### Step 2 — Load zones.json

Resolve zone for each shipment using `f"{origin_city}_{destination_city}"` as key. Default zone 3 for any missing pair.

### Step 3 — Filter shipments

`company == "MegaRetail_Co"`, `date.year == 2023`, `date.month in {10,11,12}`, `shipment_class == "standard"` → **327 rows**.

### Step 4 — Compute per-carrier totals

For all 327 shipments, compute both standard and express totals under each carrier's pricing:

| Carrier          | Standard total | Express total | Δ (express − standard) |
|---|---|---|---|
| FastShip         | 58,914.97      | 106,046.95    | 47,131.98               |
| ReliableExpress  | 73,631.82      | 111,265.23    | 37,633.41               |
| BudgetFreight    | 54,766.42      | 120,486.11    | 65,719.70               |
| **PrimeLogistics** | **62,825.68** | **101,331.08** | **38,505.40**          |

### Step 5 — Identify cheapest carrier under express

**PrimeLogistics** has the lowest express total (101,331.08 EUR), beating FastShip by ~4,716 EUR.

### Step 6 — Compute cost difference

cost_difference = PrimeLogistics express total − PrimeLogistics standard total  
= 101,331.08 − 62,825.68 = **38,505.40**

## Answer

```
PrimeLogistics:38505.40
```

### Key failure modes

**Trap 1 — Weight break ordering**: agents who apply the express multiplier first, then the weight discount, get inflated discounts and wrong carrier rankings (especially for FastShip and PrimeLogistics which have the largest weight discounts).

**Trap 2 — BudgetFreight handling fee on standard**: agents who only apply the 1.5% handling to express shipments underestimate BudgetFreight's standard total, artificially narrowing the gap and potentially misranking carriers.

**Trap 3 — PrimeLogistics zone premium scope**: the 5.00 EUR surcharge applies per-shipment for zones 4–5 under express only. Applying it to all zones or to standard as well shifts PrimeLogistics costs upward and may cause FastShip to appear cheaper.

**Trap 4 — ReliableExpress flat surcharge**: the 2.50 EUR fuel surcharge applies per-shipment to express only. Over 327 shipments this is 817.50 EUR — enough to change the ranking if missed.

**Trap 5 — Using assigned carrier**: the question asks which carrier *would have been* cheapest, i.e., all shipments evaluated under each of the four carriers' pricing in full, not just the carrier already assigned in the data.
