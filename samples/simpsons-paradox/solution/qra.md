# QRA: Simpson's Paradox in a Clinical Trial

## Question
A clinical trial dataset shows the overall effect of a treatment on patient recovery rates. Analyze the relationship between treatment and recovery, and determine whether the treatment is actually beneficial.

## Reasoning
This requires recognizing a NESTED Simpson's Paradox:
1. Overall: trt=60.0% vs ctrl=44.9% — treatment appears beneficial
2. Per age_group alone: young=BETTER (86.6% vs 66.1%), middle=WORSE, old=WORSE
   → Stratifying by age_group alone is INSUFFICIENT — young group still looks positive
3. Within young patients: mild cases are 80% treated, severe cases only 10% treated
   → `severity` is a second confounder creating a within-young paradox
4. Stratify by age_group × severity — all 6 strata show treatment is harmful:
   young+mild 90.2% vs 94.3%, young+severe 42.2% vs 55.8%, etc.
5. Both confounders must be identified: `age_group` (primary) and `severity` (secondary)
6. Mechanism: mild+young patients (high recovery) are treated 80% of the time, inflating the young
   treated rate; only severity-stratified analysis reveals treatment's true harm
7. A naive analyst reports overall=positive; a partial analyst only finds age_group

## Answer
```json
{
  "overall_treatment_effect": "positive",
  "stratified_treatment_effect": "negative in all age×severity subgroups",
  "confounding_variables": ["age_group", "severity"],
  "correct_conclusion": "treatment is harmful",
  "paradox_detected": true
}
```
