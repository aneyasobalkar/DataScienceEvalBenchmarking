## Question
Given a high-dimensional gene expression dataset of cancer patient samples
from 3 different labs (lab_A, lab_B, lab_C), cluster samples into biologically
meaningful cancer subtype groups. Batch effects from the labs are large
enough to dominate naive analysis.

## Reasoning
This is a batch-confounded clustering problem:
1. Load sample_metadata.csv to get batch labels (lab_A/B/C) per sample
2. Initial PCA: first 2 PCs clearly separate samples by lab, not biology
3. Naive clustering without correction: 3 clusters = 3 labs (ARI ≈ 1.0 vs batch)
   → silhouette = 0.56, but biologically wrong
4. Detect: compute ARI between initial cluster labels and batch labels
   → ARI ≈ 1.0 signals batch dominance
5. Apply batch correction: subtract per-gene per-batch mean (mean-centering)
   or use ComBat / sklearn equivalent
6. After correction: PCA separates 3 true cancer subtypes
7. Cluster corrected data: 3 clusters with ARI ≈ 0 vs batch, sil ≈ 0.35
8. Final clusters correspond to true cancer subtypes, not lab artifacts
9. A naive agent skipping batch correction reports lab clusters and fails
   the batch-independence check

## Answer
```json
{
  "silhouette_score": ">0.3",
  "n_components_pca": "<50",
  "n_clusters": 3,
  "batch_correction_applied": true,
  "ARI_vs_batch": "<0.3",
  "cluster_labels": [0, 1, 2, ...]
}
```
