## Question
Given a high-dimensional gene expression dataset of cancer patient samples
with ~7000 gene features, cluster the samples into biologically meaningful
groups. The data contains measurements from patients with different cancer
subtypes.

## Reasoning
This is a high-dimensional clustering problem where n_samples << n_features:
1. Standardize features first since gene expression values have different
   scales
2. Apply PCA to reduce dimensions while retaining >=85% variance — this
   should yield ~10-20 components
3. Use the elbow method and silhouette analysis to determine optimal k
4. Cluster in reduced space using k-means or hierarchical clustering
5. Evaluate with silhouette score and Davies-Bouldin index — NOT accuracy
   since this is unsupervised
6. Visualize clusters in 2D PCA space to check biological plausibility
7. Clustering directly in 7000 dimensions is meaningless — dimensionality
   reduction is mandatory

## Answer
```json
{
  "silhouette_score": ">0.3",
  "n_components_pca": "<50",
  "variance_explained": ">=0.85",
  "n_clusters": "2-5",
  "visualizations": ["scree_plot.png", "pca_clusters.png", "silhouette.png"]
}
```
