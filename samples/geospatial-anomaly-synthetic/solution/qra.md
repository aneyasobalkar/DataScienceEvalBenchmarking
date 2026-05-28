# QRA: Anomalous Route Detection — San Francisco Synthetic Trajectories

## Question

Given synthetic GPS trajectory data from delivery drivers in San Francisco with `time_of_day` and `driver_experience` metadata, identify the 5 anomalous routes that take a significantly longer path than expected for their origin–destination pair.

## Reasoning

1. Use **Haversine formula** for geographic distances — Euclidean distance on lat/lon is incorrect.
2. Compute total path length per route by summing Haversine distances between consecutive GPS points.
3. Snap start/end coordinates to a 0.01-degree grid (round to 2 decimal places) to identify OD pairs.
4. **Discover confounders by EDA** — compare mean route lengths across time_of_day and driver_experience groups per OD pair. Senior routes are ~30% longer; evening adds ~20%. The instruction does NOT tell you which confounders exist.
5. **Naive z-score (OD pair only) fails** — confounder variance (senior 30% longer, evening 20% longer) hides anomalies; all anomaly naive z-scores ≈ 1.17, well below 2.0.
6. **Stratify by OD pair × time_of_day × driver_experience** — within the junior×morning stratum, std drops to ~25 m (±1%), exposing anomalies at z ≈ 2.82.
6. Use **z > 2.5** as the detection threshold. With 5–8 routes per stratum, the mathematical upper bound on any normal route's z-score is √(n−1) ≤ √7 ≈ 2.65; any anomaly above this bound is a genuine outlier. The window z ∈ (2.5, 2.82) gives exact match with zero false positives.

## Answer

```json
{
  "anomalous_route_ids": [39, 79, 119, 159, 199],
  "n_anomalous_routes": 5,
  "distance_method": "haversine",
  "confounders_controlled": ["time_of_day", "driver_experience"],
  "detection_method": "stratified z-score > 2.5 per OD×time_of_day×driver_experience stratum"
}
```

### Per-OD statistics

| OD pair | Anomaly path | jm mean±std | all mean±std | Naive z | Strat z |
|---|---|---|---|---|---|
| FiDi→Mission | 6,314 m | 4,741±22 m | 5,497±672 m | 1.18 | 2.83 |
| SoMa→Castro | 4,844 m | 3,452±21 m | 4,116±606 m | 1.17 | 2.83 |
| NorthBeach→Sunset | 13,334 m | 9,530±38 m | 11,340±1,649 m | 1.17 | 2.83 |
| Tenderloin→Potrero | 3,199 m | 2,286±15 m | 2,732±400 m | 1.13 | 2.82 |
| Chinatown→NoeValley | 7,241 m | 5,481±38 m | 6,311±759 m | 1.19 | 2.82 |

Each anomalous route is placed in the junior×morning stratum and is 1.45× the stratum base length — within the "subtle" 1.3–1.5× range — but clearly anomalous once confounders are removed.
