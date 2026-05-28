# Geospatial Route Anomaly Detection

## Task

You are given synthetic GPS trajectory data from commuters in Beijing. The dataset contains **605 routes** with columns: `route_id`, `user_id`, `point_index`, `latitude`, `longitude`, `is_anomaly`.

**Important:** ignore the `is_anomaly` column — it is present for data integrity only and must not be used in your analysis.

Your task is to identify anomalous routes by detecting routes that are unusually long compared to other routes with the same origin-destination (OD) pair.

## Method

1. **Compute path length**: For each route, sum Haversine distances between consecutive GPS points to get total path length in meters.

2. **Define OD pairs**: Snap each route's first and last GPS point to a 0.01-degree grid cell (round to 2 decimal places). Group routes by OD pair.

3. **Detect anomalies**: For each OD pair with at least 3 routes, compute the mean and standard deviation of path lengths. Flag routes with z-score > 3.0 as anomalous.

4. **Output**: Write `/output/results.json` with:
   - `anomalous_route_ids`: list of integer route IDs flagged as anomalous (z > 3.0)
   - `method`: string describing your approach (e.g., "haversine + z-score per OD pair")
   - `od_pairs_analyzed`: integer count of OD pairs with n >= 3 routes

## Data

- `/data/trajectories.csv` — 25,005 GPS points from 605 routes (600 normal + 5 injected anomalies)
- Coordinate system: WGS84 (latitude, longitude in decimal degrees)
- Area: Beijing, China (~39.9–40.1°N, 116.2–116.5°E)
- Normal routes take a slightly indirect path (1.1–1.2× the straight-line distance)
- Anomalous routes take a dramatically longer detour (1.5–3× the normal mean for that OD pair)

## Evaluation

Your `anomalous_route_ids` list is compared against the ground truth of 5 anomalous route IDs.

A perfect detection (all 5 found, zero false positives) scores highest. Partial credit is given for finding some anomalies.

## Scoring

- **Precision**: TP / (TP + FP) — fraction of flagged routes that are true anomalies
- **Recall**: TP / (TP + FN) — fraction of true anomalies detected
- **F1 score**: harmonic mean of precision and recall
- Passing threshold: F1 ≥ 0.6

Produce at least one visualization (e.g., map of routes colored by anomaly status, or path length distribution per OD pair).
