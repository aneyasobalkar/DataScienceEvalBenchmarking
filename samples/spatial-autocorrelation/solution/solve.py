import json, warnings, numpy as np, pandas as pd, geopandas as gpd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
warnings.filterwarnings("ignore")

from libpysal.weights import Queen
from esda.moran import Moran

# ── 1. Load and filter crime data ─────────────────────────────────────────────
crimes = pd.read_csv("/data/crimes_2023.csv")
violent = crimes[crimes["primary_type"].isin(
    ["HOMICIDE", "ASSAULT", "BATTERY", "ROBBERY"]
)].copy()
violent["community_area"] = pd.to_numeric(
    violent["community_area"], errors="coerce")
violent = violent.dropna(subset=["community_area"])
violent["community_area"] = violent["community_area"].astype(int)

counts = violent.groupby("community_area").size().reset_index(name="crime_count")

# ── 2. Load population and compute crime rate per 10,000 ──────────────────────
pop = pd.read_csv("/data/community_populations.csv")
merged = pop.merge(counts, on="community_area", how="left")
merged["crime_count"] = merged["crime_count"].fillna(0)
merged["crime_rate"] = (merged["crime_count"] / merged["population"]) * 10_000

# ── 3. Load community area boundaries and join ────────────────────────────────
gdf = gpd.read_file("/data/community_areas.geojson")
gdf["area_numbe"] = pd.to_numeric(gdf["area_numbe"], errors="coerce").astype(int)
gdf = gdf.set_crs("EPSG:4326")
gdf = gdf.merge(merged, left_on="area_numbe", right_on="community_area", how="left")
gdf = gdf.sort_values("area_numbe").reset_index(drop=True)

# ── 4. Build Queen contiguity weights (row-standardized) ──────────────────────
w = Queen.from_dataframe(gdf)
w.transform = "r"

# ── 5. Compute Moran's I with 999 permutations ────────────────────────────────
np.random.seed(42)
y = gdf["crime_rate"].values
mi = Moran(y, w, transformation="r", permutations=999)

morans_i      = round(float(mi.I),      6)
z_score       = round(float(mi.z_norm), 4)
pseudo_p      = round(float(mi.p_sim),  4)
interpretation = "clustered" if mi.I > 0 and mi.p_sim < 0.05 else (
    "dispersed" if mi.I < 0 and mi.p_sim < 0.05 else "random")

# ── 6. Choropleth map ─────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(10, 12))
gdf.plot(column="crime_rate", cmap="OrRd", legend=True,
         legend_kwds={"label": "Violent crime rate per 10,000"}, ax=ax)
ax.set_title("Chicago Violent Crime Rate per 10,000 Residents\nby Community Area (2023)",
             fontsize=13)
ax.axis("off")
plt.tight_layout()
plt.savefig("/output/plots/crime_map.png", dpi=150, bbox_inches="tight")
plt.close()

# ── 7. Moran's I scatter plot ─────────────────────────────────────────────────
z  = y - y.mean()
wz = w.sparse.dot(z)   # spatial lag

fig, ax = plt.subplots(figsize=(8, 8))
ax.scatter(z, wz, color="steelblue", edgecolors="white", linewidths=0.5, s=60)
# Regression line
m, b = np.polyfit(z, wz, 1)
xr = np.linspace(z.min(), z.max(), 100)
ax.plot(xr, m * xr + b, "r-", linewidth=2, label=f"Slope = Moran's I = {morans_i:.4f}")
ax.axhline(0, color="grey", linewidth=0.7, linestyle="--")
ax.axvline(0, color="grey", linewidth=0.7, linestyle="--")
ax.set_xlabel("Violent crime rate (mean-centred)", fontsize=12)
ax.set_ylabel("Spatial lag (mean-centred)", fontsize=12)
ax.set_title(f"Moran's I Scatter Plot\nI = {morans_i:.6f}, z = {z_score:.4f}, "
             f"pseudo p = {pseudo_p:.4f}", fontsize=12)
ax.legend()
plt.tight_layout()
plt.savefig("/output/plots/morans_scatterplot.png", dpi=150, bbox_inches="tight")
plt.close()

# ── 8. Write results ──────────────────────────────────────────────────────────
results = {
    "morans_i":       morans_i,
    "z_score":        z_score,
    "pseudo_p_value": pseudo_p,
    "interpretation": interpretation,
    "weights_type":   "queen_contiguity",
}
with open("/output/results.json", "w") as f:
    json.dump(results, f, indent=2)

print(json.dumps(results, indent=2))
