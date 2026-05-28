# QRA: Anomalous Route Detection — Beijing GPS Trajectories

## Question

Given GPS trajectory data from delivery drivers in Beijing with `time_of_day` and `driver_experience` metadata, identify the 5 anomalous routes that take a significantly longer path than expected for their origin–destination pair.

## Reasoning

1. Use **Haversine formula** for geographic distances — Euclidean distance on lat/lon is incorrect.
2. Compute total path length per route by summing Haversine distances between consecutive GPS points.
3. Snap start/end coordinates to a 0.01-degree grid (round to 2 decimal places) to identify OD pairs.
4. **Naive z-score (OD pair only) fails completely** — confounder variance (senior drivers take 30% longer routes; evening adds 20%) creates an overall std of ~2,500 m per OD pair, pushing all anomaly z-scores to ~1.07, well below 2.0.
5. **Stratify by OD pair × time_of_day × driver_experience** — within each stratum the std drops to ~100 m (±1%), exposing anomalies at z ≈ 4.4.
6. Use **z > 3.5** as the detection threshold. With 20 routes per stratum, natural outliers can reach z ≈ 3.1; threshold 3.5 eliminates all false positives while anomaly z-scores of 4.4+ are clearly above it.

## Answer

```json
{
  "anomalous_route_ids": [600, 601, 602, 603, 604],
  "n_anomalous_routes": 5,
  "distance_method": "haversine",
  "confounders_controlled": ["time_of_day", "driver_experience"],
  "detection_method": "stratified z-score > 3.5 per OD×time_of_day×driver_experience stratum"
}
```

### Per-OD statistics

| OD pair | Direct | Anomaly path | jm mean±std | Naive z | Strat z |
|---|---|---|---|---|---|
| Chaoyang→Haidian | 12,972 m | 19,564 m | 13,536±116 m | 1.08 | 4.45 |
| Dongcheng→Fengtai | 8,506 m | 11,653 m | 8,771±51 m | 1.08 | 4.46 |
| Xicheng→Chaoyang | 9,356 m | 14,223 m | 9,848±140 m | 1.05 | 4.42 |
| Shijingshan→Xicheng | 12,342 m | 18,775 m | 13,013±164 m | 1.07 | 4.43 |
| Haidian→Dongcheng | 11,125 m | 16,076 m | 11,537±102 m | 1.06 | 4.45 |

Each anomalous route is placed in the junior×morning stratum and is 1.45× the stratum base length — within the "subtle" 1.3–1.5× range — but clearly anomalous (z ≈ 4.4) once confounders are removed.
