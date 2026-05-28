# Anomalous Route Detection — San Francisco GPS Trajectories

You have GPS trajectory data from delivery drivers operating in San Francisco.

## Dataset

File: `/data/trajectories.csv`

Columns:
- `user_id` — driver identifier
- `route_id` — unique route identifier
- `timestamp` — ISO 8601 timestamp of each GPS fix
- `latitude`, `longitude` — WGS84 coordinates
- `altitude` — elevation in metres
- `time_of_day` — `morning`, `afternoon`, or `evening`
- `driver_experience` — `junior` or `senior`

There are 200 routes in total.

## Task

Identify which routes are anomalous — routes that take a significantly longer path than expected between the same origin–destination pair.

Before flagging anomalies, explore whether any metadata columns in the dataset systematically affect route lengths. Account for all relevant confounders when computing expected path lengths for each route.

## Output

Save all visualisations to `/output/plots/`.

Write results to `/output/results.json`:
```json
{
  "anomalous_route_ids": [<list of integer route IDs>],
  "n_anomalous_routes": <integer>,
  "distance_method": "<distance formula used>",
  "confounders_controlled": [<list of variables controlled for>],
  "detection_method": "<brief description>"
}
```
