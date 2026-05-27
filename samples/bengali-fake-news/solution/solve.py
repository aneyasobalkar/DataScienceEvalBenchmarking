import json, os, unicodedata
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    f1_score, classification_report, confusion_matrix
)

os.makedirs("/output/plots", exist_ok=True)

# ── Load data ─────────────────────────────────────────────────────────────────
df_train = pd.read_csv("/data/train.csv")
df_val   = pd.read_csv("/data/val.csv")
df_test  = pd.read_csv("/data/test.csv")

print(f"Train: {len(df_train):,}  Val: {len(df_val):,}  Test: {len(df_test):,}")
print("Label dist (train):", df_train["label"].value_counts().to_dict())
print("Sources (train):", df_train["source"].value_counts().to_dict())

# ── Text normalisation ────────────────────────────────────────────────────────
def normalize(text):
    if not isinstance(text, str):
        return ""
    return unicodedata.normalize("NFC", text).strip()

X_train = df_train["text"].map(normalize)
X_test  = df_test["text"].map(normalize)
y_train = df_train["label"]
y_test  = df_test["label"]

# ── Visualisation 1: class distribution ──────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(12, 5))
counts_train = df_train["label"].value_counts().sort_index()
counts_test  = df_test["label"].value_counts().sort_index()
axes[0].bar(["Real (0)", "Fake (1)"], counts_train.values, color=["steelblue", "tomato"])
axes[0].set_title("Class Distribution — Train")
axes[0].set_ylabel("Count")
axes[1].bar(["Real (0)", "Fake (1)"], counts_test.values, color=["steelblue", "tomato"])
axes[1].set_title("Class Distribution — Test")
plt.tight_layout()
plt.savefig("/output/plots/class_distribution.png", dpi=100)
plt.close()

# ── Visualisation 2: source distribution ─────────────────────────────────────
src_counts = df_train["source"].value_counts()
fig, ax = plt.subplots(figsize=(12, 5))
src_counts.plot(kind="bar", ax=ax, color="steelblue")
ax.set_title("Articles per Source (Train)")
ax.set_ylabel("Count")
ax.set_xlabel("")
plt.xticks(rotation=45, ha="right")
plt.tight_layout()
plt.savefig("/output/plots/source_distribution.png", dpi=100)
plt.close()

# ── Visualisation 3: text length by class ────────────────────────────────────
fig, ax = plt.subplots(figsize=(10, 5))
for label, colour in [(0, "steelblue"), (1, "tomato")]:
    subset = df_train[df_train["label"] == label]["word_count"].clip(0, 600)
    ax.hist(subset, bins=50, alpha=0.6, color=colour, label=f"{'Real' if label==0 else 'Fake'}")
ax.set_title("Word Count Distribution by Class")
ax.set_xlabel("Word Count")
ax.set_ylabel("Frequency")
ax.legend()
plt.tight_layout()
plt.savefig("/output/plots/length_distribution.png", dpi=100)
plt.close()

# ── TF-IDF vectorisation (character n-grams) ──────────────────────────────────
print("Fitting TF-IDF vectoriser …")
vec = TfidfVectorizer(
    analyzer="char_wb",
    ngram_range=(2, 5),
    max_features=80_000,
    sublinear_tf=True,
    min_df=3,
)
X_tr_v = vec.fit_transform(X_train)
X_te_v = vec.transform(X_test)
print(f"Vocabulary size: {len(vec.vocabulary_):,}  |  Matrix: {X_tr_v.shape}")

# ── Classifier ────────────────────────────────────────────────────────────────
print("Training Logistic Regression …")
clf = LogisticRegression(class_weight="balanced", max_iter=1000, C=1.0)
clf.fit(X_tr_v, y_train)

# ── Evaluation ────────────────────────────────────────────────────────────────
y_pred   = clf.predict(X_te_v)
macro_f1 = round(float(f1_score(y_test, y_pred, average="macro")), 4)
report   = classification_report(y_test, y_pred, output_dict=True)

per_class_f1 = {
    "0": round(report["0"]["f1-score"], 4),
    "1": round(report["1"]["f1-score"], 4),
}

print(f"\nMacro F1: {macro_f1}")
print(classification_report(y_test, y_pred, target_names=["real", "fake"]))

# ── Per-source F1 ─────────────────────────────────────────────────────────────
per_source_f1 = {}
for src, grp in df_test.groupby("source"):
    preds = clf.predict(vec.transform(grp["text"].map(normalize)))
    sf1 = f1_score(grp["label"], preds, average="macro", zero_division=0)
    per_source_f1[src] = round(float(sf1), 4)
    print(f"  {src}: {sf1:.4f}  (n={len(grp)})")

# ── Visualisation 4: confusion matrix ─────────────────────────────────────────
cm = confusion_matrix(y_test, y_pred)
fig, ax = plt.subplots(figsize=(6, 5))
sns.heatmap(cm, annot=True, fmt="d", cmap="Blues",
            xticklabels=["Pred Real", "Pred Fake"],
            yticklabels=["True Real", "True Fake"], ax=ax)
ax.set_title(f"Confusion Matrix  (Macro F1={macro_f1})")
plt.tight_layout()
plt.savefig("/output/plots/confusion_matrix.png", dpi=100)
plt.close()

# ── Visualisation 5: per-source F1 ───────────────────────────────────────────
fig, ax = plt.subplots(figsize=(12, 5))
sources = list(per_source_f1.keys())
scores  = [per_source_f1[s] for s in sources]
colours = ["steelblue" if s >= 0.75 else "tomato" for s in scores]
ax.bar(sources, scores, color=colours)
ax.axhline(0.75, color="black", linestyle="--", linewidth=1, label="0.75 threshold")
ax.set_ylim(0, 1.05)
ax.set_title("Per-Source Macro F1")
ax.set_ylabel("Macro F1")
plt.xticks(rotation=45, ha="right")
ax.legend()
plt.tight_layout()
plt.savefig("/output/plots/per_source_f1.png", dpi=100)
plt.close()

# ── Write results ─────────────────────────────────────────────────────────────
results = {
    "macro_f1":       macro_f1,
    "per_class_f1":   per_class_f1,
    "per_source_f1":  per_source_f1,
    "model":          "LogisticRegression(class_weight=balanced, C=1.0, max_iter=1000)",
    "vectorizer":     "TfidfVectorizer(analyzer=char_wb, ngram_range=(2,5), max_features=80000, sublinear_tf=True)",
}
with open("/output/results.json", "w") as f:
    json.dump(results, f, indent=2)

print(f"\nDone. Macro F1 = {macro_f1}  |  Plots saved to /output/plots/")
