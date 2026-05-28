# A/B Test Analysis

An e-commerce company ran a 14-day A/B test on a new checkout flow. Your job is to analyze the experiment results and determine whether the new checkout flow should be shipped to all users.

## Data

All files are in `/data/`.

**`experiment_results.csv`** — user-level experiment data with columns:
- `user_id` — unique user identifier
- `timestamp` — when the user entered the experiment
- `group` — `control` (old checkout) or `treatment` (new checkout)
- `converted` — whether the user completed a purchase: `1` = yes, `0` = no
- `revenue` — revenue generated (0 if not converted)
- `page_views` — number of pages viewed during the session
- `session_duration` — session length in seconds
- `bounce_rate` — proportion of sessions that bounced

**`experiment_config.json`** — experiment configuration including expected traffic split, primary metric, secondary metrics, and significance level.

## Your Task

1. **Validate the experiment** — before drawing any conclusions, verify that the experiment was conducted correctly and the data is trustworthy.

2. **Analyze the results** — for each metric in the config, determine whether there is a statistically significant difference between groups.

3. **Make a recommendation** — based on your full analysis, recommend whether to ship the new checkout flow or not.

4. **Save visualizations** to `/output/plots/` showing your analysis.

5. **Write your results** to `/output/results.json` in exactly this format:

```json
{
  "srm_detected": <true or false>,
  "srm_pvalue": <float>,
  "early_stopping_detected": <true or false>,
  "multiple_testing_violation": <true or false>,
  "bonferroni_corrected_pvalue": <float>,
  "recommendation": "<ship or do not ship>",
  "reason": "<one sentence explaining the primary reason>"
}
```
