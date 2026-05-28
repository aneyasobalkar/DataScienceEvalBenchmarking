# Pharma Fee Calculator

You have access to a clinical trial billing database and its accompanying documentation.

## Data

Files are at `/data/`:

- `trials.csv` — 50,000 clinical trial billing records with columns:
  `trial_id`, `company`, `drug_class`, `trial_phase`, `country_code`, `aci`,
  `patient_count`, `base_fee_eur`, `date`
- `billing_manual.md` — fee calculation rules and regional compliance policy

**Read `billing_manual.md` first.** The manual defines how fees are computed.
Do not assume you understand the fee structure from the data alone.

## Task

For **BioPharm_Corp** in **Q3 2023** (July, August, September):

What would be the total billing delta if the surcharge rule for Phase III
trials in EU countries changed from **2.5%** to **4.0%**?

Report the delta broken down by drug class.

## Output

Write your answer to `/app/answer.txt` in **exactly** this format:

```
[drug_class_i: delta_i, drug_class_j: delta_j, ...]
```

- Sort drug classes **ascending by delta amount**
- Round all delta amounts to **2 decimal places**
- Use the drug class names exactly as they appear in the data

Example format (not real values):
```
[Cardiology: 1234.56, Oncology: 2345.67, Rare_Disease: 3456.78]
```
