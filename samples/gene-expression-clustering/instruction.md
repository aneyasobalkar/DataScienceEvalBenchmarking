# Gene Expression Clustering

You are a data scientist tasked with discovering hidden structure in a cancer genomics dataset.

## Dataset

The dataset contains gene expression measurements from cancer patient samples collected across three independent laboratories.

- `/data/gene_expression.csv` — expression matrix; rows are patient samples, columns are genes
- `/data/sample_metadata.csv` — per-sample metadata with `sample_id` and `batch` (lab origin: lab_A, lab_B, lab_C)

The data has many thousands of gene features and a relatively small number of samples. Each value represents the measured expression level of a gene in that patient. Samples were processed in different labs, and technical batch effects may be present.

## Your Task

Cluster the patient samples into biologically meaningful groups that may correspond to distinct cancer subtypes or molecular phenotypes.

1. **Explore the data** — understand dimensions, distributions, and any technical artifacts that may be present.

2. **Check for batch effects** — examine whether samples cluster by lab of origin before any biological analysis. Batch effects can dominate the signal and must be corrected.

3. **Preprocess and correct** — apply batch correction if needed, then reduce dimensions. High-dimensional data requires dimensionality reduction before clustering.

4. **Determine the number of clusters** — do not assume a fixed number; use the data to guide your choice.

5. **Cluster the samples** — apply a suitable algorithm in the reduced space.

6. **Evaluate** — use metrics appropriate for unsupervised learning. Verify that your final clusters are not driven by batch (lab origin) but by biological signal.

7. **Visualize** — save all plots to `/output/plots/`.

8. **Write results** to `/output/results.json` with at minimum:
```json
{
  "silhouette_score": <float, 4 decimal places>,
  "davies_bouldin_score": <float, 4 decimal places>,
  "n_clusters": <int>,
  "n_components_pca": <int>,
  "variance_explained": <float, 4 decimal places>,
  "algorithm": "<description>",
  "cluster_labels": [<int>, ...],
  "batch_correction_applied": <bool>
}
```

## Constraints

- Lightweight methods only — no neural networks or deep learning
- All plots must be saved to `/output/plots/` before writing `results.json`
