# Gene Expression Clustering

You are a data scientist tasked with discovering hidden structure in a cancer genomics dataset.

## Dataset

The dataset contains gene expression measurements from cancer patient samples.

- `/data/gene_expression.csv` — expression matrix; rows are patient samples, columns are genes

The data has many thousands of gene features and a relatively small number of samples. Each value represents the measured expression level of a gene in that patient.

## Your Task

Cluster the patient samples into biologically meaningful groups that may correspond to distinct cancer subtypes or molecular phenotypes.

1. **Explore the data** — understand its dimensions, distributions, and any structure that may be present.

2. **Preprocess and reduce** — high-dimensional data requires careful treatment before clustering. Choose an appropriate strategy.

3. **Determine the number of clusters** — do not assume a fixed number; use the data to guide your choice.

4. **Cluster the samples** — apply a suitable algorithm in the reduced space.

5. **Evaluate** — use metrics appropriate for unsupervised learning (there are no ground-truth labels).

6. **Visualize** — save all plots to `/output/plots/`.

7. **Write results** to `/output/results.json` with at minimum:
```json
{
  "silhouette_score": <float, 4 decimal places>,
  "davies_bouldin_score": <float, 4 decimal places>,
  "n_clusters": <int>,
  "n_components_pca": <int>,
  "variance_explained": <float, 4 decimal places>,
  "algorithm": "<description>"
}
```

## Constraints

- Lightweight methods only — no neural networks or deep learning
- All plots must be saved to `/output/plots/` before writing `results.json`
