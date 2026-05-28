# QRA: Pharma Fee Calculator — BioPharm_Corp Q3 2023 Surcharge Delta

## Question

For BioPharm_Corp in Q3 2023, what would be the total billing delta if the surcharge rule for Phase III trials in EU countries changed from 2.5% to 4.0%? Report by drug class sorted ascending by delta amount.

## Reasoning

1. **Read billing_manual.md** to extract fee rules — the instruction says to read it first, and it contains two traps:

   **Trap 1 — Drug class multipliers (Section 3):** Each therapeutic area has a multiplier applied to the base fee *before* the surcharge. These are written in prose, not a table:
   - Oncology: ×1.3
   - Cardiology: ×1.1
   - Neurology: ×1.0
   - Immunology: ×1.2
   - Rare_Disease: ×1.5

   Agents who skip this section will compute surcharges on the raw base fee × patient_count, getting wrong deltas.

   **Trap 2 — ACI condition (Section 5):** The EU Phase III surcharge only applies when ACI code is **A, B, or C**. ACI codes D and E are exempt (biosimilar/generic streamlined pathway). This condition is buried in natural prose, not highlighted. Agents who apply the surcharge to all Phase III EU rows will overcount surcharge-eligible rows and produce incorrect deltas.

2. **Filter** `trials.csv` to:
   - `company == "BioPharm_Corp"`
   - `date` in Q3 2023: year=2023, month in {7, 8, 9}
   → 437 rows

3. **Compute adjusted fee** per row:
   ```
   adjusted_fee = base_fee_eur × patient_count × multiplier[drug_class]
   ```

4. **Identify surcharge-eligible rows** — all three conditions must hold:
   - `trial_phase == "Phase_III"`
   - `country_code` in {DE, FR, NL, ES, IT}
   - `aci` in {A, B, C}
   → 36 of 437 rows qualify

5. **Compute fees under old rate (2.5%) and new rate (4.0%)**:
   ```
   fee_old = adjusted_fee × (1 + 0.025 × surcharge_flag)
   fee_new = adjusted_fee × (1 + 0.040 × surcharge_flag)
   delta   = fee_new − fee_old
           = adjusted_fee × 0.015 × surcharge_flag
   ```

6. **Aggregate delta by drug_class**, sort ascending.

7. **Red herrings to ignore**:
   - Section 4: Phase IV legacy fee (€500 flat) — irrelevant, no Phase IV rows qualify
   - Section 6: Currency conversion — all fees already in EUR, no conversion needed

## Answer

```
[Neurology: 4223.36, Immunology: 5934.23, Oncology: 7485.73, Rare_Disease: 8169.56, Cardiology: 10556.83]
```

### Per-drug-class breakdown

| Drug Class   | Surcharge rows | Delta (2.5%→4.0%) |
|---|---|---|
| Neurology    | 7              | 4,223.36          |
| Immunology   | 7              | 5,934.23          |
| Oncology     | 8              | 7,485.73          |
| Rare_Disease | 6              | 8,169.56          |
| Cardiology   | 8              | 10,556.83         |

**Why delta varies by class despite similar row counts**: the delta per row is
`adjusted_fee × 0.015` where `adjusted_fee = base_fee × patient_count × multiplier`.
Cardiology's ×1.1 multiplier combined with higher per-row base amounts produces
the largest aggregate delta; Neurology's ×1.0 produces the smallest.

### Key failure modes

- **ACI trap missed**: applying surcharge to all Phase III EU rows (not just ACI∈{A,B,C}) gives wrong totals
- **Multiplier missed**: omitting therapeutic area multipliers underscales all deltas
- **Both missed**: doubly wrong
- **Wrong date filter**: using full-year 2023 instead of Q3 inflates row counts
