# QRA: Simpson's Paradox in a Clinical Trial

## Question
A clinical trial dataset shows the overall effect of a treatment on patient recovery rates. Analyze the relationship between treatment and recovery, and determine whether the treatment is actually beneficial.

## Reasoning
This requires recognizing Simpson's Paradox:
1. First compute overall recovery rate by treatment group — treatment appears beneficial overall (~52% vs ~42%)
2. Recognize this alone is insufficient — check for confounding variables
3. Stratify by every categorical variable in the dataset (age_group, severity, hospital)
4. Find the subgroup where direction reverses — overall looks positive but treatment is worse within every age group
5. Identify the confounding variable causing the reversal: `age_group`
6. Understand the mechanism: young patients (high natural recovery ~80%) were disproportionately given treatment (69% treated), while old patients (low recovery ~25%) were mostly controls (80% control). This inflates the treatment arm's overall recovery rate.
7. Report the CORRECT conclusion based on stratified analysis, not the misleading overall rate
8. A naive analyst who only computes overall correlation reaches the wrong answer — treatment appears beneficial when it is actually harmful in every age subgroup

## Answer
```json
{
  "overall_treatment_effect": "positive",
  "stratified_treatment_effect": "negative in all subgroups",
  "confounding_variable": "age_group",
  "correct_conclusion": "treatment is harmful",
  "paradox_detected": true
}
```
