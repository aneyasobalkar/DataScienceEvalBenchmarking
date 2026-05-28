import math, json, os
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from collections import defaultdict

os.makedirs('/output/plots', exist_ok=True)

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlam/2)**2
    return R * 2 * math.asin(math.sqrt(a))

df = pd.read_csv('/data/trajectories.csv')

# Compute path length and OD pair for each route
route_ids = df['route_id'].unique()
route_stats = {}
for rid in route_ids:
    sub = df[df['route_id'] == rid].sort_values('timestamp')
    lats = sub['latitude'].values
    lons = sub['longitude'].values
    plen = sum(haversine(lats[i-1], lons[i-1], lats[i], lons[i]) for i in range(1, len(lats)))
    # Snap start/end to 0.01-degree grid for OD pair
    origin = (round(lats[0], 2), round(lons[0], 2))
    dest   = (round(lats[-1], 2), round(lons[-1], 2))
    route_stats[rid] = {
        'path_length_m': plen,
        'od_pair': f"{origin}->{dest}",
        'start_lat': lats[0], 'start_lon': lons[0],
        'end_lat': lats[-1], 'end_lon': lons[-1],
    }

# Group by OD pair and detect anomalies via z-score
od_groups = defaultdict(list)
for rid, s in route_stats.items():
    od_groups[s['od_pair']].append((rid, s['path_length_m']))

anomalous_route_ids = []
n_od_pairs = 0

for od, pairs in od_groups.items():
    if len(pairs) < 3:
        continue
    n_od_pairs += 1
    lengths = np.array([p[1] for p in pairs])
    mean_len = lengths.mean()
    std_len = lengths.std()
    if std_len < 1:
        continue
    for rid, plen in pairs:
        z = (plen - mean_len) / std_len
        if z > 2.0:
            anomalous_route_ids.append(int(rid))

anomalous_route_ids = sorted(set(anomalous_route_ids))

# Plot 1: path length distribution per OD pair
od_list = sorted(od_groups.keys())
fig, axes = plt.subplots(1, len(od_list), figsize=(4*len(od_list), 4), sharey=False)
for ax, od in zip(axes, od_list):
    pairs = od_groups[od]
    lengths = [p[1]/1000 for p in pairs]
    colors = ['red' if p[0] in anomalous_route_ids else 'steelblue' for p in pairs]
    ax.bar(range(len(lengths)), sorted(lengths), color=sorted(colors, reverse=True))
    ax.set_title(od[:30], fontsize=7)
    ax.set_xlabel('Route rank')
    ax.set_ylabel('Path length (km)')
plt.suptitle('Path Length by OD Pair (red = anomalous)', fontsize=10)
plt.tight_layout()
plt.savefig('/output/plots/path_lengths.png', dpi=100, bbox_inches='tight')
plt.close()

# Plot 2: map of route start/end points
fig, ax = plt.subplots(figsize=(10, 10))
for rid, s in route_stats.items():
    color = 'red' if rid in anomalous_route_ids else 'steelblue'
    alpha = 0.8 if rid in anomalous_route_ids else 0.3
    ax.plot([s['start_lon'], s['end_lon']], [s['start_lat'], s['end_lat']],
            color=color, alpha=alpha, linewidth=1)
ax.set_xlabel('Longitude'); ax.set_ylabel('Latitude')
ax.set_title('Route Start→End Points (red=anomalous, blue=normal)')
from matplotlib.lines import Line2D
legend = [Line2D([0],[0],color='red',lw=2,label='Anomalous'),
          Line2D([0],[0],color='steelblue',lw=2,label='Normal')]
ax.legend(handles=legend)
plt.tight_layout()
plt.savefig('/output/plots/route_map.png', dpi=100, bbox_inches='tight')
plt.close()

results = {
    'n_anomalous_routes': len(anomalous_route_ids),
    'anomalous_route_ids': anomalous_route_ids,
    'distance_method': 'haversine',
    'detection_method': f'z-score > 2.0 on path length per OD pair ({n_od_pairs} pairs)',
    'n_od_pairs': n_od_pairs,
}

with open('/output/results.json', 'w') as f:
    json.dump(results, f, indent=2)

print(f"Analyzed {n_od_pairs} OD pairs")
print(f"Anomalous routes ({len(anomalous_route_ids)}): {anomalous_route_ids}")
