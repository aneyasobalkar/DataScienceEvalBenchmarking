# Anomalous Delivery Route Detection

## Task

A logistics company has GPS data from 50 delivery drivers operating in San Francisco. You have been asked to identify which driver routes are anomalous — taking significantly longer paths than expected between the same pickup and delivery locations.

## Data

The file `/data/trajectories.csv` contains GPS traces from 200 delivery routes:

| Column | Description |
|--------|-------------|
| `user_id` | Driver ID (0–49) |
| `route_id` | Unique route identifier |
| `timestamp` | ISO 8601 datetime of each GPS ping |
| `latitude` | GPS latitude (decimal degrees) |
| `longitude` | GPS longitude (decimal degrees) |
| `altitude` | Altitude in meters |

Each route consists of 20–50 GPS points recorded every 30 seconds. Routes go between specific office locations and warehouse locations around the city.

## What to Detect

Some drivers are taking detours that make their routes significantly longer than other drivers traveling the same office-to-warehouse path. Identify which routes are anomalous.

## Output

Write your results to `/output/results.json`:

```json
{
  "n_anomalous_routes": <int>,
  "anomalous_route_ids": [<list of route_id integers>],
  "distance_method": "<method used: 'haversine' or 'euclidean'>",
  "detection_method": "<description of your approach>"
}
```

Also produce:
- A map visualization saved to `/output/plots/` showing normal vs anomalous routes
- A path length distribution plot saved to `/output/plots/`

## Notes

- Routes between the same pair of locations should have similar path lengths
- A route is anomalous if its path length is unusually long compared to other routes between the same locations
- There are exactly 5 anomalous routes per origin-destination pair
- Make sure your distance calculations are accurate for geographic coordinates
