import json, math, os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import folium
from scipy import stats as sp_stats

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    a = math.sin(dp/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dl/2)**2
    return R * 2 * math.asin(math.sqrt(a))

df = pd.read_csv("/data/trajectories.csv")
df = df.sort_values(["route_id", "timestamp"])

# Haversine path length per route
path_lengths = {}
for rid, grp in df.groupby("route_id"):
    g = grp.sort_values("timestamp")
    lats, lons = g.latitude.values, g.longitude.values
    pl = sum(haversine(lats[i], lons[i], lats[i+1], lons[i+1]) for i in range(len(lats)-1))
    path_lengths[rid] = pl

# OD pair key (snap to 0.01° grid) + confounder metadata
od_keys, meta = {}, {}
for rid, grp in df.groupby("route_id"):
    g = grp.sort_values("timestamp")
    o = (round(g.latitude.iloc[0], 2), round(g.longitude.iloc[0], 2))
    d = (round(g.latitude.iloc[-1], 2), round(g.longitude.iloc[-1], 2))
    od_keys[rid] = (o, d)
    meta[rid] = {
        "time_of_day":       g.time_of_day.iloc[0],
        "driver_experience": g.driver_experience.iloc[0],
    }

# Stratified z-score: group by OD pair × time_of_day × driver_experience
THRESHOLD = 3.5   # strict threshold needed for 20-route strata
groups = {}
for rid in path_lengths:
    tod = meta[rid]["time_of_day"]
    exp = meta[rid]["driver_experience"]
    key = (od_keys[rid], tod, exp)
    groups.setdefault(key, []).append(rid)

anomalous = set()
for rids in groups.values():
    if len(rids) < 3:
        continue
    lengths = np.array([path_lengths[r] for r in rids])
    z = sp_stats.zscore(lengths)
    for r, zi in zip(rids, z):
        if zi > THRESHOLD:
            anomalous.add(r)

anomalous = sorted(anomalous)
print(f"Anomalous routes ({len(anomalous)}): {anomalous}")

os.makedirs("/output/plots", exist_ok=True)

# Path length distribution plot
fig, axes = plt.subplots(1, 5, figsize=(20, 4))
od_pairs = sorted(set(od_keys[r] for r in path_lengths))
for ax, od in zip(axes, od_pairs):
    rids = [r for r, k in od_keys.items() if k == od]
    lengths = [path_lengths[r] for r in rids]
    colors = ["red" if r in anomalous else "steelblue" for r in rids]
    ax.bar(range(len(rids)), sorted(lengths), color=sorted(colors, reverse=True))
    ax.set_title(f"{od[0]}→{od[1]}", fontsize=7)
    ax.set_xlabel("Route (sorted)")
    ax.set_ylabel("Path length (m)")
plt.tight_layout()
plt.savefig("/output/plots/path_lengths.png", dpi=100)
plt.close()

# Folium map
center_lat = df.latitude.mean()
center_lon = df.longitude.mean()
m = folium.Map(location=[center_lat, center_lon], zoom_start=12)
for rid, grp in df.groupby("route_id"):
    g = grp.sort_values("timestamp")
    coords = list(zip(g.latitude.values, g.longitude.values))
    color = "red" if rid in anomalous else "blue"
    weight = 3 if rid in anomalous else 1
    folium.PolyLine(coords, color=color, weight=weight, opacity=0.7).add_to(m)
m.save("/output/plots/route_map.html")

results = {
    "anomalous_route_ids":    anomalous,
    "n_anomalous_routes":     len(anomalous),
    "distance_method":        "haversine",
    "confounders_controlled": ["time_of_day", "driver_experience"],
    "detection_method":       f"stratified z-score > {THRESHOLD} per OD×time_of_day×driver_experience stratum",
}
with open("/output/results.json", "w") as f:
    json.dump(results, f, indent=2)
print(json.dumps(results, indent=2))
