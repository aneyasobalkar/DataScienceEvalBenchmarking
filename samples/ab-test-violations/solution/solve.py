import json, os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy.stats import chi2_contingency, chi2, ttest_ind

os.makedirs('/output/plots', exist_ok=True)

df  = pd.read_csv('/data/experiment_results.csv')
with open('/data/experiment_config.json') as f:
    cfg = json.load(f)

ctrl = df[df.group == 'control']
trt  = df[df.group == 'treatment']
alpha = cfg['significance_level']          # 0.05

# ── 1. Sample Ratio Mismatch (SRM) ───────────────────────────────────────────
n_c, n_t = len(ctrl), len(trt)
n_total   = n_c + n_t
expected  = n_total * cfg['expected_split']
chi2_srm  = (n_c - expected)**2 / expected + (n_t - expected)**2 / expected
p_srm     = chi2.sf(chi2_srm, 1)
srm_detected = bool(p_srm < alpha)

print(f"SRM: control={n_c}, treatment={n_t}, expected={expected:.0f} each")
print(f"     chi2={chi2_srm:.1f}, p={p_srm:.2e}, detected={srm_detected}")

# Plot group sizes
fig, ax = plt.subplots(figsize=(6, 4))
ax.bar(['Control', 'Treatment', 'Expected (each)'],
       [n_c, n_t, expected],
       color=['steelblue', 'tomato', 'gray'], edgecolor='white')
ax.axhline(expected, color='gray', linestyle='--', alpha=0.7)
ax.set_ylabel('Users')
ax.set_title(f'Group Sizes — SRM {"DETECTED" if srm_detected else "not detected"} (p={p_srm:.2e})')
ax.grid(True, alpha=0.3, axis='y')
for i, v in enumerate([n_c, n_t, expected]):
    ax.text(i, v + 100, f'{v:,.0f}', ha='center', va='bottom')
plt.tight_layout()
plt.savefig('/output/plots/group_sizes.png', dpi=100)
plt.close()

# ── 2. Cumulative p-value (early stopping check) ──────────────────────────────
df['date'] = pd.to_datetime(df['timestamp']).dt.date
dates = sorted(df['date'].unique())
cum_pvals = []
for date in dates:
    sub = df[df.date <= date]
    c2 = sub[sub.group == 'control'];  t2 = sub[sub.group == 'treatment']
    tbl = [[c2.converted.sum(), len(c2) - c2.converted.sum()],
           [t2.converted.sum(), len(t2) - t2.converted.sum()]]
    _, p, _, _ = chi2_contingency(tbl, correction=False)
    cum_pvals.append(p)

# Early stopping: p crossed 0.05 before the last day
early_stopping_detected = bool(any(p < alpha for p in cum_pvals[:-1]))
first_cross = next((i+1 for i, p in enumerate(cum_pvals[:-1]) if p < alpha), None)

print(f"\nEarly stopping: first p<0.05 at day {first_cross}, detected={early_stopping_detected}")

fig, ax = plt.subplots(figsize=(10, 4))
ax.plot(range(1, len(dates)+1), cum_pvals, 'o-', color='steelblue', lw=2)
ax.axhline(alpha, color='red', linestyle='--', label=f'α={alpha}')
if first_cross:
    ax.axvline(first_cross, color='orange', linestyle=':', alpha=0.8,
               label=f'First crossing (day {first_cross})')
ax.set_xlabel('Day of experiment')
ax.set_ylabel('Cumulative p-value (primary metric)')
ax.set_title('Cumulative P-value Over Time — Early Stopping Risk')
ax.legend()
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('/output/plots/pvalue_over_time.png', dpi=100)
plt.close()

# ── 3. Multiple testing ────────────────────────────────────────────────────────
metrics    = [cfg['primary_metric']] + cfg['secondary_metrics']
n_metrics  = len(metrics)
alpha_bonf = alpha / n_metrics

metric_pvals = {}
for m in metrics:
    if m == 'converted':
        tbl = [[ctrl[m].sum(), n_c - ctrl[m].sum()],
               [trt[m].sum(),  n_t - trt[m].sum()]]
        _, p, _, _ = chi2_contingency(tbl, correction=False)
    else:
        _, p = ttest_ind(ctrl[m], trt[m])
    metric_pvals[m] = p
    sig = 'sig' if p < alpha else 'n.s.'
    bonf_sig = 'sig after Bonf' if p < alpha_bonf else 'n.s. after Bonf'
    print(f"  {m}: p={p:.4f}  {sig}  {bonf_sig}")

primary_p = metric_pvals[cfg['primary_metric']]
bonferroni_corrected_pvalue = float(min(primary_p * n_metrics, 1.0))

# Violation: primary metric nominally significant but not after Bonferroni correction
multiple_testing_violation = bool(primary_p < alpha)
print(f"\nMultiple testing: n_metrics={n_metrics}, alpha_bonf={alpha_bonf:.4f}")
print(f"  primary p={primary_p:.4f}, corrected p={bonferroni_corrected_pvalue:.4f}")
print(f"  violation={multiple_testing_violation}")

# Plot metric p-values
fig, ax = plt.subplots(figsize=(8, 4))
colors = ['tomato' if p < alpha else 'steelblue' for p in metric_pvals.values()]
bars = ax.bar(list(metric_pvals.keys()), list(metric_pvals.values()),
              color=colors, edgecolor='white')
ax.axhline(alpha,       color='red',    linestyle='--', label=f'α={alpha}')
ax.axhline(alpha_bonf,  color='orange', linestyle='--', label=f'Bonferroni α/n={alpha_bonf:.4f}')
ax.set_ylabel('p-value')
ax.set_title(f'P-values for All Metrics ({n_metrics} tested, Bonferroni threshold={alpha_bonf:.4f})')
ax.legend()
ax.grid(True, alpha=0.3, axis='y')
plt.tight_layout()
plt.savefig('/output/plots/metrics.png', dpi=100)
plt.close()

# ── Recommendation ────────────────────────────────────────────────────────────
if srm_detected:
    recommendation = 'do not ship'
    reason = 'experiment invalid due to sample ratio mismatch'
elif early_stopping_detected:
    recommendation = 'do not ship'
    reason = 'experiment may have been stopped early — results unreliable'
elif primary_p >= alpha_bonf:
    recommendation = 'do not ship'
    reason = 'primary metric not significant after Bonferroni correction'
else:
    recommendation = 'ship'
    reason = 'primary metric significant after correction with no validity issues'

print(f"\nRecommendation: {recommendation}")
print(f"Reason: {reason}")

results = {
    'srm_detected':               srm_detected,
    'srm_pvalue':                 float(round(p_srm, 6)),
    'early_stopping_detected':    early_stopping_detected,
    'multiple_testing_violation': multiple_testing_violation,
    'bonferroni_corrected_pvalue': bonferroni_corrected_pvalue,
    'recommendation':             recommendation,
    'reason':                     reason,
}

with open('/output/results.json', 'w') as f:
    json.dump(results, f, indent=2)

print("\nResults:")
print(json.dumps(results, indent=2))
