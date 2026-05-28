import json
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns

os.makedirs('/output/plots', exist_ok=True)

df = pd.read_csv('/data/clinical_trial.csv')

# ── Overall recovery rate by treatment ────────────────────────────────────────
overall = df.groupby('treatment')['recovered'].mean()
overall_effect = 'positive' if overall[1] > overall[0] else 'negative'

print("=== Overall recovery rate ===")
print(f"  Control   (0): {overall[0]:.4f}")
print(f"  Treatment (1): {overall[1]:.4f}")
print(f"  Overall effect: {overall_effect}")

# ── Stratified analysis by every categorical variable ─────────────────────────
cat_cols = ['age_group', 'severity', 'hospital']
reversals = {}

for col in cat_cols:
    groups = df[col].unique()
    effects = {}
    all_negative = True
    for g in groups:
        sub = df[df[col] == g].groupby('treatment')['recovered'].mean()
        if 1 not in sub or 0 not in sub:
            continue
        gap = sub[1] - sub[0]
        effects[str(g)] = round(float(gap), 4)
        if gap >= 0:
            all_negative = False
    reversals[col] = {'effects': effects, 'all_reversed': all_negative}
    print(f"\n=== Stratified by {col} ===")
    for g, v in effects.items():
        print(f"  {g}: {v:+.4f}")
    print(f"  All groups show reversal: {all_negative}")

# ── Identify the confounding variable ─────────────────────────────────────────
confounder = None
for col, info in reversals.items():
    if info['all_reversed']:
        confounder = col
        break

paradox_detected = confounder is not None
stratified_effect = 'negative' if paradox_detected else overall_effect
correct_conclusion = 'treatment is harmful' if paradox_detected else 'treatment is beneficial'

print(f"\nConfounding variable: {confounder}")
print(f"Paradox detected: {paradox_detected}")
print(f"Correct conclusion: {correct_conclusion}")

# ── Plot 1: Overall recovery rate comparison ───────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(12, 5))

ax = axes[0]
bars = ax.bar(['Control', 'Treatment'],
              [overall[0], overall[1]],
              color=['steelblue', 'tomato'], edgecolor='white', width=0.5)
ax.set_ylim(0, 1)
ax.set_ylabel('Recovery Rate')
ax.set_title('Overall Recovery Rate by Treatment')
for bar, val in zip(bars, [overall[0], overall[1]]):
    ax.text(bar.get_x() + bar.get_width()/2, val + 0.01,
            f'{val:.3f}', ha='center', va='bottom', fontweight='bold')
ax.grid(True, alpha=0.3, axis='y')

# ── Plot 2: Stratified by age_group ──────────────────────────────────────────
ax = axes[1]
age_order = ['young', 'middle', 'old']
strat = df.groupby(['age_group', 'treatment'])['recovered'].mean().unstack()
strat = strat.reindex(age_order)

x = np.arange(len(age_order))
w = 0.35
ax.bar(x - w/2, strat[0], w, label='Control', color='steelblue', edgecolor='white')
ax.bar(x + w/2, strat[1], w, label='Treatment', color='tomato', edgecolor='white')
ax.set_xticks(x)
ax.set_xticklabels(age_order)
ax.set_ylim(0, 1)
ax.set_ylabel('Recovery Rate')
ax.set_title("Recovery Rate by Age Group\n(within each group, treatment is worse)")
ax.legend()
ax.grid(True, alpha=0.3, axis='y')

plt.suptitle("Simpson's Paradox: Treatment Appears Beneficial Overall But Harmful in Every Subgroup",
             fontsize=11, y=1.02)
plt.tight_layout()
plt.savefig('/output/plots/overall_vs_stratified.png', dpi=100, bbox_inches='tight')
plt.close()

# ── Plot 3: Treatment assignment by age group (shows confounding) ─────────────
fig, ax = plt.subplots(figsize=(7, 4))
assign = df.groupby(['age_group', 'treatment']).size().unstack(fill_value=0)
assign = assign.reindex(age_order)
assign_pct = assign.div(assign.sum(axis=1), axis=0)
assign_pct.plot(kind='bar', ax=ax, color=['steelblue', 'tomato'],
                edgecolor='white', legend=True)
ax.set_xticklabels(age_order, rotation=0)
ax.set_ylabel('Proportion')
ax.set_title('Treatment Assignment by Age Group\n(young patients disproportionately treated)')
ax.legend(['Control', 'Treatment'])
ax.grid(True, alpha=0.3, axis='y')
plt.tight_layout()
plt.savefig('/output/plots/treatment_assignment.png', dpi=100)
plt.close()

# ── Write results ─────────────────────────────────────────────────────────────
results = {
    'overall_treatment_effect':    overall_effect,
    'stratified_treatment_effect': stratified_effect + ' in all subgroups' if paradox_detected else stratified_effect,
    'confounding_variable':        confounder,
    'correct_conclusion':          correct_conclusion,
    'paradox_detected':            paradox_detected,
}

with open('/output/results.json', 'w') as f:
    json.dump(results, f, indent=2)

print("\nResults written to /output/results.json")
print(json.dumps(results, indent=2))
