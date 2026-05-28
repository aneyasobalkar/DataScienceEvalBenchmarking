# QRA: Spatial Autocorrelation — Chicago Violent Crime Clustering

## Question

Given Chicago crime incident data for 2023, compute the global Moran's I statistic
to determine whether violent crimes cluster spatially or are randomly distributed
across community areas. Report the Moran's I value, z-score, pseudo p-value, and
interpretation.

## Reasoning

### Step 1 — Read spatial_methods.md

The document defines:
- Moran's I formula: I = (n/S₀) × (z′Wz / z′z) — S₀ normalization is critical
- Why crime rates (not raw counts) are required — population confounding
- Why Queen contiguity is appropriate for community area polygons
- Why permutation test is required over normal distribution test
- Why row standardization must be applied

### Step 2 — Filter to violent crimes and compute crime rates

Filter `crimes_2023.csv` to:
```python
primary_type in ["HOMICIDE", "ASSAULT", "BATTERY", "ROBBERY"]
```
→ 78,577 of 263,352 records are violent crimes

Aggregate counts by `community_area`, join with `community_populations.csv`,
compute:
```python
crime_rate = (crime_count / population) * 10_000
```

All 77 community areas present; no missing values.

**Trap 1 — Raw counts**: Using `crime_count` directly as the variable produces
a different Moran's I (driven by population density clustering, not crime risk).

### Step 3 — Build Queen contiguity weights

```python
from libpysal.weights import Queen
w = Queen.from_dataframe(gdf)   # from the sorted GeoDataFrame
w.transform = "r"               # row-standardize
```

Queen contiguity: 77 areas, mean 5.12 neighbours, no islands. S₀ = n = 77
after row standardization.

**Trap 2 — Distance or KNN weights**: These are not appropriate for administrative
polygons, produce asymmetric neighbour counts, and give different Moran's I values.

**Trap 3 — Skipping row standardization**: Without `w.transform = "r"`, S₀ ≠ n
and the statistic is not comparable across datasets.

### Step 4 — Compute Moran's I with permutation test

```python
np.random.seed(42)
mi = Moran(y, w, transformation="r", permutations=999)
```

**Trap 4 — Normal distribution test**: `mi.p_norm` uses a normal approximation
inappropriate for spatially dependent data. The correct output is `mi.p_sim`
(pseudo p-value from permutation test).

**Trap 5 — Wrong formula**: Implementations that compute z′Wz/z′z without the
n/S₀ factor produce systematically biased values.

### Step 5 — Interpret results

- I = 0.574421 >> E[I] = −0.013 → strong positive autocorrelation
- z = 8.17, pseudo p = 0.001 → statistically significant clustering
- Interpretation: **clustered** (high-crime areas adjacent to high-crime areas)

### Step 6 — Produce visualizations

Choropleth map: `crime_rate` column plotted with `OrRd` colormap, shows South
Side and West Side hotspots.

Moran scatter plot: z (mean-centred crime rate) on x-axis, spatial lag Wz on
y-axis. Positive slope = clustering. Slope ≈ Moran's I.

## Answer

```json
{
  "morans_i": 0.574421,
  "z_score": 8.1692,
  "pseudo_p_value": 0.001,
  "interpretation": "clustered",
  "weights_type": "queen_contiguity"
}
```

### Why this task defeats naive implementations

A model that "knows Moran's I" but applies it naively will:
1. Use raw crime counts → slightly different I, same sign but wrong magnitude
2. Use k-nearest neighbours or inverse distance weights → different neighbourhood
   structure → different I (typically lower, ~0.4)
3. Report `p_norm` instead of `p_sim` → same p-value direction but wrong methodology
4. Skip `np.random.seed` → non-reproducible pseudo p-value (though still < 0.05)
5. Miss S₀ normalization → wrong I entirely

The combination of (a) correct population normalization, (b) Queen contiguity with
row standardization, and (c) permutation test with fixed seed is what produces
the exact value 0.574421. Any one error shifts the result outside the ±0.005 window.

### Reference

- Moran, P.A.P. (1950). Notes on continuous stochastic phenomena. *Biometrika* 37, 17–23.
- Wang, B. et al. (2024). ScienceAgentBench: Toward Rigorous Assessment of Language
  Agents for Data-Driven Scientific Discovery. arXiv:2410.05080.
- PySAL/esda documentation: https://esda.readthedocs.io/
