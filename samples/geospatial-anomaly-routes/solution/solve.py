import math, json, os
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from collections import defaultdict

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlam/2)**2
    return R * 2 * math.asin(math.sqrt(a))

df = pd.read_csv('/data/trajectories.csv')

route_ids = df['route_id'].unique()
route_stats = {}
for rid in route_ids:
    sub = df[df['route_id'] == rid].sort_values('point_index')
    lats = sub['latitude'].values
    lons = sub['longitude'].values
    plen = sum(haversine(lats[i-1], lons[i-1], lats[i], lons[i]) for i in range(1, len(lats)))
    origin = (round(lats[0], 2), round(lons[0], 2))
    dest = (round(lats[-1], 2), round(lons[-1], 2))
    route_stats[rid] = {
        'path_length_m': plen,
        'origin': origin,
        'dest': dest,
        'od_pair': f"{origin}->{dest}",
        'start_lat': lats[0], 'start_lon': lons[0],
        'end_lat': lats[-1], 'end_lon': lons[-1]
    }

od_groups = defaultdict(list)
for rid, s in route_stats.items():
    od_groups[s['od_pair']].append((rid, s['path_length_m']))

anomalous_route_ids = []
od_pairs_analyzed = 0

for od, pairs in od_groups.items():
    if len(pairs) < 3:
        continue
    od_pairs_analyzed += 1
    lengths = np.array([p[1] for p in pairs])
    mean_len = lengths.mean()
    std_len = lengths.std()
    if std_len < 1:
        continue
    for rid, plen in pairs:
        z = (plen - mean_len) / std_len
        if z > 3.0:
            anomalous_route_ids.append(int(rid))

anomalous_route_ids = sorted(set(anomalous_route_ids))

os.makedirs('/output', exist_ok=True)

# Plot 1: Path length distribution with anomalies highlighted
all_lengths = [(rid, s['path_length_m']) for rid, s in route_stats.items()]
normal_lens = [pl for rid, pl in all_lengths if rid not in anomalous_route_ids]
anom_lens = [pl for rid, pl in all_lengths if rid in anomalous_route_ids]

fig, axes = plt.subplots(1, 2, figsize=(14, 5))
axes[0].hist(normal_lens, bins=40, color='steelblue', alpha=0.7, label=f'Normal (n={len(normal_lens)})')
if anom_lens:
    axes[0].hist(anom_lens, bins=10, color='red', alpha=0.9, label=f'Anomalous (n={len(anom_lens)})')
axes[0].set_xlabel('Path Length (m)')
axes[0].set_ylabel('Count')
axes[0].set_title('Route Path Length Distribution')
axes[0].legend()

# Plot 2: Map of route start points
colors = ['red' if rid in anomalous_route_ids else 'steelblue' for rid in route_stats]
start_lats = [s['start_lat'] for s in route_stats.values()]
start_lons = [s['start_lon'] for s in route_stats.values()]
axes[1].scatter(start_lons, start_lats, c=colors, alpha=0.5, s=15)
axes[1].set_xlabel('Longitude')
axes[1].set_ylabel('Latitude')
axes[1].set_title('Route Start Points (red = anomalous)')

plt.tight_layout()
plt.savefig('/output/anomaly_detection.png', dpi=100, bbox_inches='tight')
plt.close()

results = {
    'anomalous_route_ids': anomalous_route_ids,
    'method': 'haversine path length + z-score per OD pair (threshold z > 3.0)',
    'od_pairs_analyzed': od_pairs_analyzed
}

with open('/output/results.json', 'w') as f:
    json.dump(results, f, indent=2)

print(f"Analyzed {od_pairs_analyzed} OD pairs")
print(f"Anomalous routes: {anomalous_route_ids}")
