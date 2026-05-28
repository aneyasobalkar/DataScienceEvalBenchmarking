# Clinical Trial Analysis

You are a data scientist analyzing the results of a clinical trial that tested a new treatment for patient recovery.

## Dataset

The dataset contains records from 10,000 patients enrolled in the trial. Data is at `/data/clinical_trial.csv`.

Columns:
- `patient_id` — unique patient identifier
- `age_group` — patient age category: `young`, `middle`, or `old`
- `treatment` — whether the patient received the new treatment: `1` = treated, `0` = control
- `recovered` — whether the patient recovered: `1` = recovered, `0` = did not recover
- `severity` — disease severity at enrollment: `mild` or `severe`
- `hospital` — treating hospital: `A`, `B`, or `C`

## Your Task

1. **Analyze the relationship between treatment and recovery** — determine whether the new treatment is beneficial for patients.

2. **Investigate potential factors** — explore whether any patient characteristics affect the relationship between treatment and recovery.

3. **Report your conclusion** — based on your analysis, state clearly whether the treatment is beneficial or harmful.

4. **Save visualizations** to `/output/plots/` illustrating your findings.

5. **Write your results** to `/output/results.json` in exactly this format:

```json
{
  "overall_treatment_effect": "<positive or negative>",
  "stratified_treatment_effect": "<positive or negative>",
  "confounding_variable": "<variable name or null>",
  "correct_conclusion": "<treatment is beneficial or treatment is harmful>",
  "paradox_detected": <true or false>
}
```

Use `"paradox_detected": false` and `"confounding_variable": null` if you find no confounding.
