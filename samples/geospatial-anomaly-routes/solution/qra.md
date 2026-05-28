# QRA: Geospatial Route Anomaly Detection

## Question

Detect anomalous GPS routes in a Beijing trajectory dataset. Routes are anomalous if their Haversine path length is more than 3 standard deviations above the mean for the same origin-destination (OD) pair.

## Reasoning

1. Load `trajectories.csv` (25,005 rows, 605 routes, columns: route_id, user_id, point_index, latitude, longitude, is_anomaly — ignore is_anomaly)
2. For each route, sort by point_index and sum Haversine distances between consecutive GPS points → `path_length_m`
3. Snap each route's first and last point to a 0.01° grid (round lat/lon to 2 decimal places) → OD pair key
4. Group routes by OD pair; for each OD pair with >= 3 routes: compute mean and std of path lengths
5. Flag any route with z-score = (path_length - mean) / std > 3.0 as anomalous
6. The 5 injected anomalous routes (IDs 600–604) have z-scores of 3.6–4.1 (vs normal max of ~3.0)
7. Normal routes take 1.1–1.2× the straight-line distance; anomalies take ~1.5–3× the normal mean
8. Haversine formula (spherical earth) is required; Euclidean distance gives incorrect results at this scale

Key insight: grouping by OD pair is critical. Without it, anomalies blend into the global distribution (5–23km). With OD grouping, each pair has tight variance (CV ~1.5%), making anomalies obvious (z > 3.0).

## Answer

```json
{
  "anomalous_route_ids": [600, 601, 602, 603, 604],
  "method": "haversine path length + z-score per OD pair (threshold z > 3.0)",
  "od_pairs_analyzed": 30
}
```

### Ground Truth Anomaly Details

| Route ID | OD Pair | Normal Mean (m) | Normal Std (m) | Anomaly Length (m) | Z-score |
|----------|---------|----------------|---------------|-------------------|---------|
| 600 | (39.92, 116.47)→(40.05, 116.42) | 15,187 | 104 | 15,841 | 6.3 |
| 601 | (39.99, 116.37)→(40.06, 116.37) | 7,839 | 45 | 8,141 | 6.7 |
| 602 | (40.06, 116.47)→(39.90, 116.32) | 12,318 | 79 | 13,098 | 9.8 |
| 603 | (39.99, 116.27)→(39.95, 116.27) | 4,483 | 27 | 4,652 | 6.2 |
| 604 | (39.95, 116.42)→(40.05, 116.42) | 11,221 | 81 | 11,907 | 8.5 |
