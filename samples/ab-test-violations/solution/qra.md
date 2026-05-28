# QRA: A/B Test Validity Violations

## Question
An e-commerce company ran an A/B test on a new checkout flow. Analyze the experiment results and determine whether the new checkout flow should be shipped.

## Reasoning
This requires checking experiment validity before analyzing results:
1. Check for Sample Ratio Mismatch — run chi-squared test on group sizes vs expected 50/50 split. Control has 28,000 users, treatment has 22,000 — a massive deviation (chi²=720, p≈1e-158)
2. Check for early stopping — plot cumulative p-value over time. The p-value first crosses 0.05 at day 9, indicating the experiment could have been stopped prematurely
3. Check for multiple testing — the config lists 4 metrics (converted + 3 secondary). Without Bonferroni correction, the primary metric p=0.023 looks significant. After correction (α/4 = 0.0125), p=0.023 > 0.0125 — not significant
4. The SRM alone is sufficient to invalidate the experiment — do not ship
5. A naive analyst just runs a t-test on conversion rates, sees p=0.023 < 0.05, and recommends shipping — this is wrong

## Answer
```json
{
  "srm_detected": true,
  "srm_pvalue": 1.34e-158,
  "early_stopping_detected": true,
  "multiple_testing_violation": true,
  "bonferroni_corrected_pvalue": 0.0932,
  "recommendation": "do not ship",
  "reason": "experiment invalid due to sample ratio mismatch"
}
```
