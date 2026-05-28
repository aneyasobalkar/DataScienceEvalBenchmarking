# QRA: Anomalous Delivery Route Detection

## Question

Given GPS trajectory data from delivery drivers operating in San Francisco, identify which routes are anomalous — taking significantly longer paths than expected between the same origin-destination pairs.

## Reasoning

This is a geospatial analysis problem with a critical trap:

1. Load `trajectories.csv` (7,158 rows, 200 routes with 20–50 GPS points each)
2. **Use Haversine formula** for distances — NOT Euclidean. Treating lat/long as regular Cartesian coordinates gives systematically wrong results for geographic data.
3. For each route, compute total path length by summing Haversine distances between consecutive GPS points
4. Identify origin-destination (OD) pairs by snapping start and end coordinates to a 0.01-degree grid
5. For each OD pair, compute mean and standard deviation of path lengths across all routes
6. Flag routes where path length > mean + 2 × std as anomalous (z-score > 2.0)
7. Visualize on a map — anomalous routes appear as dramatic spatial outliers

Naive agents use Euclidean distance (treating lat/lon as Cartesian) and may get wrong anomaly flags, especially since Euclidean distance between GPS coordinates does not preserve physical distances correctly.

Dataset structure:
- 5 OD pairs × (35 normal + 5 anomalous) = 200 routes total
- Normal routes: path length ≈ 1.1–1.2× direct distance (CV ~0.01–0.02)
- Anomalous routes: path length ≈ 2.7–3.3× the normal mean for the same OD pair

## Answer

```json
{
  "n_anomalous_routes": 25,
  "anomalous_route_ids": [35, 36, 37, 38, 39, 75, 76, 77, 78, 79,
                          115, 116, 117, 118, 119, 155, 156, 157, 158, 159,
                          195, 196, 197, 198, 199],
  "distance_method": "haversine",
  "detection_method": "z-score > 2.0 on path length per OD pair (5 pairs)"
}
```

### OD Pair Details

| OD Pair | Direct dist | Normal mean | Normal std | Anomaly mean | Ratio | Anomaly z range |
|---------|------------|-------------|-----------|--------------|-------|-----------------|
| Embarcadero→Bayview | 6,669m | 6,786m | 85m | 19,583m | 2.89× | 2.40–2.94 |
| SoMa→NorthEast | 5,962m | 6,083m | 75m | 17,847m | 2.93× | 2.21–3.15 |
| NorthBeach→WestPortal | 8,577m | 8,743m | 146m | 26,745m | 3.06× | 2.05–2.87 |
| Mission→GlenPark | 5,478m | 5,573m | 90m | 16,815m | 3.02× | 2.11–3.26 |
| HayesValley→Presidio | 5,031m | 5,106m | 58m | 15,218m | 2.98× | 2.16–3.23 |
