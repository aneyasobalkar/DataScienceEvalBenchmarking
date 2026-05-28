# QRA: A/B Test Validity Violations

## Question
An e-commerce company ran an A/B test on a new checkout flow. Analyze the experiment results and determine whether the new checkout flow should be shipped.

## Reasoning
This requires checking experiment validity before analyzing results:
1. Check for Sample Ratio Mismatch — run chi-squared test on group sizes vs expected 50/50 split. Control has 25,800 users, treatment has 24,200 — looks roughly balanced, but chi²=51.2 (p≈8e-13) reveals a real SRM. The SRM is subtle: eyeballing group sizes alone will not catch it.
2. Check for early stopping — plot cumulative p-value over time. The p-value first crosses 0.05 at day 10 of 14, indicating the experiment could have been stopped prematurely.
3. Check for multiple testing — the config lists 4 metrics (converted + 3 secondary). Without Bonferroni correction, the primary metric p=0.0218 looks significant. After correction (α/4 = 0.0125), p=0.0218 > 0.0125 — not significant (Bonferroni p=0.0870).
4. All three violations must be detected: SRM, early stopping, and multiple testing.
5. The SRM alone is sufficient to invalidate the experiment — do not ship.
6. A naive analyst runs a t-test, sees treatment at 10.2% vs control 9.6%, p=0.022 < 0.05, and recommends shipping — this is wrong.

## Answer
```json
{
  "srm_detected": true,
  "srm_pvalue": 8.34e-13,
  "early_stopping_detected": true,
  "multiple_testing_violation": true,
  "bonferroni_corrected_pvalue": 0.0870,
  "recommendation": "do not ship",
  "reason": "experiment invalid due to sample ratio mismatch"
}
```
