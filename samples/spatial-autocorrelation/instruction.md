# Spatial Autocorrelation — Chicago Crime Analysis

You have Chicago crime incident data for 2023 and community area geographic boundaries.

## Data

All files are at `/data/`:

- `crimes_2023.csv` — 263,352 crime incident records for 2023 with columns:
  `id`, `primary_type`, `community_area`, `year`, `date`
- `community_areas.geojson` — polygon boundaries for all 77 Chicago community areas
  (property `area_numbe` = community area number, `community` = area name)
- `community_populations.csv` — 2020 Census population per community area
  (`community_area`, `population`)
- `spatial_methods.md` — methodology documentation — **READ THIS BEFORE ANY ANALYSIS**

**Read `spatial_methods.md` first.** The correct statistical methods are defined
there and cannot be inferred from general knowledge alone.

## Task

Determine whether **violent crimes** in 2023 cluster spatially across Chicago's
77 community areas, or whether they are distributed randomly.

Violent crime types: `HOMICIDE`, `ASSAULT`, `BATTERY`, `ROBBERY`

Use the global spatial autocorrelation statistic described in the methods document.
Account for population differences across community areas when computing crime
prevalence. Use appropriate spatial neighbourhood definitions and statistical
significance testing as described in the documentation.

## Output

Save visualisations to `/output/plots/`:
- `crime_map.png` — choropleth map of violent crime rates across community areas
- `morans_scatterplot.png` — Moran's I scatter plot (spatial lag vs. crime rate)

Write results to `/output/results.json`:
```json
{
  "morans_i": <float, 6 decimal places>,
  "z_score": <float, 4 decimal places>,
  "pseudo_p_value": <float, 4 decimal places>,
  "interpretation": <"clustered" or "dispersed" or "random">,
  "weights_type": <string describing the spatial weights used>
}
```
