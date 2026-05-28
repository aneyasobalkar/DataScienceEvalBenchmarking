# Spatial Autocorrelation Methods for Crime Analysis

## 1. What Is Spatial Autocorrelation?

Spatial autocorrelation measures the degree to which a variable's values at nearby
locations are similar to (positive autocorrelation) or different from (negative
autocorrelation) its values at more distant locations. Tobler's First Law of
Geography states that "everything is related to everything else, but near things
are more related than distant things." Spatial autocorrelation quantifies the
extent to which this law holds for a specific phenomenon across a specific set
of spatial units.

For crime analysis, spatial autocorrelation answers the question: do high-crime
neighbourhoods tend to be adjacent to other high-crime neighbourhoods, and
low-crime to low-crime (clustering)? Or do high-crime areas tend to neighbour
low-crime areas (dispersion)? Or is there no discernible spatial pattern (random)?

---

## 2. Moran's I — Formula and Interpretation

The global Moran's I statistic is the most widely used measure of spatial
autocorrelation. It is defined as:

    I = (n / S₀) × (z′Wz / z′z)

where:
- **n** — number of spatial units (here, community areas)
- **S₀** — the sum of all spatial weights: S₀ = Σᵢ Σⱼ wᵢⱼ
- **z** — the vector of mean-centred values: zᵢ = yᵢ − ȳ (where ȳ is the global mean)
- **W** — the spatial weights matrix (see Section 4)
- **z′Wz** — the spatial lag product: Σᵢ Σⱼ wᵢⱼ zᵢ zⱼ
- **z′z** — the total sum of squares: Σᵢ zᵢ²

**Interpretation of I:**
- I > 0: positive spatial autocorrelation (similar values cluster together)
- I < 0: negative spatial autocorrelation (dissimilar values are adjacent)
- I ≈ E[I]: no spatial autocorrelation, where E[I] = −1/(n−1) ≈ −0.013 for n=77

The S₀ normalization term is critical. Omitting it — that is, computing z′Wz/z′z
without dividing by n/S₀ — produces an incorrect statistic because the raw value
depends on the scale of the weights matrix. For row-standardized weights (see below),
S₀ = n and the formula simplifies, but the S₀ term must still be included in
implementations that do not assume a particular normalization.

---

## 3. Why Crime Rates, Not Raw Counts

A fundamental error in spatial crime analysis is to use raw crime counts rather
than crime rates. Community areas vary enormously in population — Chicago's Loop
has over 43,000 residents while Burnside has fewer than 3,000. A community area
with 500 crimes and a population of 5,000 has a crime rate of 1,000 per 10,000
residents, whereas one with 500 crimes and 100,000 residents has a rate of 50
per 10,000 — a twenty-fold difference.

Using raw counts confounds the spatial pattern of crime risk with the spatial
pattern of population density. The resulting Moran's I would reflect the clustering
of population, not the clustering of crime propensity. To measure whether crime
risk (not crime volume) is spatially autocorrelated, you must normalize by population:

    crime_rate = (crime_count / population) × 10,000

This produces rates per 10,000 residents, which are directly comparable across
areas of different sizes.

---

## 4. Spatial Weights Matrix — Queen Contiguity

The spatial weights matrix W defines the neighbourhood structure. The entry wᵢⱼ
specifies how much influence area j exerts on area i. There are many ways to
define spatial weights; the appropriate choice depends on the geometry of the
spatial units and the underlying process being studied.

**Queen contiguity** defines two polygonal areas as neighbours if they share any
boundary length or a corner point (analogous to the queen piece in chess, which can
move in any direction). For community areas — which are administrative polygons
sharing edges — Queen contiguity is the natural choice: it captures genuine spatial
adjacency without imposing an arbitrary distance threshold.

Alternative weight definitions that are inappropriate for this context:

- **Distance-based (inverse distance)**: assigns weights based on distance between
  centroids. This imposes a continuous decay function that is not appropriate for
  administrative units with sharp boundaries, and requires a bandwidth parameter
  choice that introduces arbitrariness.

- **K-nearest neighbours (KNN)**: each area has exactly k neighbours regardless of
  geographic configuration. This produces an asymmetric matrix by default and does
  not respect the actual polygon boundaries.

For community areas bounded by streets and waterways, Queen contiguity correctly
captures which areas share residents' daily movement corridors.

---

## 5. Row Standardization

After constructing the binary contiguity matrix (wᵢⱼ = 1 if areas i and j are
neighbours, 0 otherwise), the weights must be row-standardized. Row standardization
divides each weight by the row sum, so that all weights in row i sum to 1:

    wᵢⱼ (row-standardized) = wᵢⱼ / Σⱼ wᵢⱼ

Row standardization has two important consequences. First, it ensures that the
spatial lag of y — the weighted average of neighbours' values — has the same
units and scale as y itself, facilitating interpretation. Second, it makes the
Moran's I statistic comparable across datasets with different numbers of neighbours
per unit. Without row standardization, units with many neighbours would exert
disproportionate influence on the statistic.

---

## 6. Permutation Test for Statistical Significance

There are two approaches to testing whether the observed Moran's I is statistically
significant:

**Analytical (normal distribution) test**: under the null hypothesis of no spatial
autocorrelation, I is approximately normally distributed with known mean and variance.
This yields a z-score and p-value from the standard normal distribution. However,
this approximation relies on an assumption that the data values are independently
and identically distributed — an assumption that spatial data almost never satisfies.
Crime rates in adjacent areas are not independent; they share common demographic,
economic, and policing conditions.

**Permutation (pseudo) test**: under the null hypothesis of spatial randomness,
the observed values are randomly reassigned to the spatial units many times (typically
999 permutations), and Moran's I is recomputed for each permuted dataset. The
empirical distribution of these permuted I values serves as the reference distribution.
The pseudo p-value is the proportion of permuted I values that are as extreme as or
more extreme than the observed I:

    pseudo p-value = (number of permutations with I ≥ I_observed + 1) / (permutations + 1)

The permutation test makes no distributional assumptions and is always preferred
for spatial data. A pseudo p-value below 0.05 indicates statistically significant
spatial autocorrelation at the 5% level.

---

## 7. Implementation Reference

The Python library **esda** (part of the PySAL ecosystem) implements Moran's I
with permutation testing. The spatial weights matrix should be built using
**libpysal.weights.Queen**, applied to the GeoDataFrame of community area polygons,
and then row-standardized (transformation = "r"). The **esda.Moran** class accepts
the outcome variable array, the weights object, and the number of permutations.

Key outputs: `Moran.I` (the statistic), `Moran.z_norm` (z-score from normal
approximation), `Moran.p_sim` (pseudo p-value from permutation test).

---

*End of spatial methods documentation.*
