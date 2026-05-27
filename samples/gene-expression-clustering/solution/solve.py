import json, os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.cm as cm
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score, silhouette_samples, davies_bouldin_score

os.makedirs("/output/plots", exist_ok=True)

# ── Load ──────────────────────────────────────────────────────────────────────
df = pd.read_csv("/data/gene_expression.csv", index_col="sample_id")
print(f"Loaded: {df.shape[0]} samples × {df.shape[1]} genes")

# ── Standardise ───────────────────────────────────────────────────────────────
scaler = StandardScaler()
X = scaler.fit_transform(df.values)

# ── PCA — use scree plot to select components ─────────────────────────────────
pca_full = PCA(random_state=42).fit(X)
cumvar   = np.cumsum(pca_full.explained_variance_ratio_)

# Elbow: find where incremental variance gain drops below 1%
diffs  = np.diff(pca_full.explained_variance_ratio_)
# Use the first component where individual variance < 1% as the elbow cutoff
# but always keep at least 2 and cap at the 85%-variance point
n_85   = int(np.searchsorted(cumvar, 0.85)) + 1
elbow  = int(np.argmax(diffs < 0.01)) + 1          # first component below 1% gain
n_comp = max(2, min(elbow, n_85))                  # at least 2, at most the 85% cutoff
var_exp = float(cumvar[n_comp - 1])
print(f"PCA: {n_comp} components, variance explained = {var_exp:.4f}")

# ── Scree plot ─────────────────────────────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(12, 4))
plot_n = min(30, len(pca_full.explained_variance_ratio_))
axes[0].bar(range(1, plot_n + 1), pca_full.explained_variance_ratio_[:plot_n], color="steelblue")
axes[0].axvline(n_comp, color="tomato", linestyle="--", label=f"Selected: {n_comp}")
axes[0].set_xlabel("Component")
axes[0].set_ylabel("Explained Variance Ratio")
axes[0].set_title("Scree Plot")
axes[0].legend()
axes[1].plot(range(1, plot_n + 1), cumvar[:plot_n], marker="o", color="steelblue")
axes[1].axvline(n_comp, color="tomato", linestyle="--", label=f"n={n_comp} ({var_exp:.1%} var)")
axes[1].set_xlabel("Number of Components")
axes[1].set_ylabel("Cumulative Variance")
axes[1].set_title("Cumulative Variance Explained")
axes[1].legend()
plt.tight_layout()
plt.savefig("/output/plots/scree_plot.png", dpi=100)
plt.close()

# ── Project to reduced space ───────────────────────────────────────────────────
pca    = PCA(n_components=n_comp, random_state=42)
X_pca  = pca.fit_transform(X)

# ── Optimal k — silhouette sweep ──────────────────────────────────────────────
k_range    = range(2, min(8, df.shape[0]))
sil_scores = []
inertias   = []
for k in k_range:
    km  = KMeans(n_clusters=k, random_state=42, n_init=20)
    lbl = km.fit_predict(X_pca)
    sil_scores.append(silhouette_score(X_pca, lbl))
    inertias.append(km.inertia_)

best_k = list(k_range)[int(np.argmax(sil_scores))]
print(f"Optimal k={best_k}  silhouette scores: {[round(s, 3) for s in sil_scores]}")

# ── Final clustering ───────────────────────────────────────────────────────────
km     = KMeans(n_clusters=best_k, random_state=42, n_init=20)
labels = km.fit_predict(X_pca)
sil    = round(float(silhouette_score(X_pca, labels)), 4)
db     = round(float(davies_bouldin_score(X_pca, labels)), 4)
print(f"Silhouette: {sil}   Davies-Bouldin: {db}")

# ── PCA scatter coloured by cluster ───────────────────────────────────────────
palette = cm.tab10.colors
fig, ax = plt.subplots(figsize=(8, 6))
for k in range(best_k):
    mask = labels == k
    ax.scatter(X_pca[mask, 0], X_pca[mask, 1],
               c=[palette[k]], label=f"Cluster {k+1}", s=70, alpha=0.85, edgecolors="white")
ax.set_xlabel(f"PC1 ({pca.explained_variance_ratio_[0]:.1%} var)")
ax.set_ylabel(f"PC2 ({pca.explained_variance_ratio_[1]:.1%} var)")
ax.set_title(f"PCA Clusters (k={best_k}, silhouette={sil})")
ax.legend()
plt.tight_layout()
plt.savefig("/output/plots/pca_clusters.png", dpi=100)
plt.close()

# ── Silhouette diagram ─────────────────────────────────────────────────────────
sil_vals = silhouette_samples(X_pca, labels)
fig, ax  = plt.subplots(figsize=(8, 5))
y_lower  = 10
for k in range(best_k):
    vals    = np.sort(sil_vals[labels == k])
    y_upper = y_lower + len(vals)
    ax.fill_betweenx(np.arange(y_lower, y_upper), 0, vals,
                     facecolor=palette[k], edgecolor=palette[k], alpha=0.7)
    ax.text(-0.05, (y_lower + y_upper) / 2, str(k + 1))
    y_lower = y_upper + 10
ax.axvline(sil, color="red", linestyle="--", label=f"Mean={sil}")
ax.set_xlabel("Silhouette coefficient")
ax.set_ylabel("Cluster")
ax.set_title(f"Silhouette Diagram (k={best_k})")
ax.legend()
plt.tight_layout()
plt.savefig("/output/plots/silhouette.png", dpi=100)
plt.close()

# ── Results ───────────────────────────────────────────────────────────────────
results = {
    "silhouette_score":     sil,
    "davies_bouldin_score": db,
    "n_clusters":           best_k,
    "n_components_pca":     n_comp,
    "variance_explained":   round(var_exp, 4),
    "algorithm":            f"KMeans(k={best_k}, n_init=20) on {n_comp}-component PCA",
}
with open("/output/results.json", "w") as f:
    json.dump(results, f, indent=2)

print(f"\nDone. Silhouette={sil}  k={best_k}  n_comp={n_comp}  var={var_exp:.4f}")
print("Plots:", os.listdir("/output/plots"))
