import json, os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.signal import find_peaks
from scipy.optimize import curve_fit

os.makedirs("/output/plots", exist_ok=True)

# ── Load ──────────────────────────────────────────────────────────────────────
df = pd.read_csv("/data/dielectron.csv")
M  = df["M"].dropna().values
print(f"Events: {len(M):,}  M range: {M.min():.2f} – {M.max():.2f} GeV")

# ── Overview: log-spaced histogram reveals peaks at all scales ────────────────
bins_log  = np.logspace(np.log10(M.min()), np.log10(M.max()), 400)
cnt_ov, edg_ov = np.histogram(M, bins=bins_log)
cen_ov = 0.5 * (edg_ov[:-1] + edg_ov[1:])
den_ov = cnt_ov / np.diff(edg_ov)        # events / GeV (density)

fig, axes = plt.subplots(1, 2, figsize=(14, 5))
for ax, yscale, title in zip(
    axes,
    ["linear", "log"],
    ["Dielectron Invariant Mass Spectrum (linear)",
     "Dielectron Invariant Mass Spectrum (log scale)"],
):
    ax.plot(cen_ov, den_ov, linewidth=0.8, color="steelblue")
    ax.set_yscale(yscale)
    ax.set_xlabel("Invariant Mass M (GeV)")
    ax.set_ylabel("Events / GeV")
    ax.set_title(title)
plt.tight_layout()
plt.savefig("/output/plots/mass_spectrum.png", dpi=100)
plt.close()
print("Saved mass_spectrum.png")

# ── Peak detection on log-density ─────────────────────────────────────────────
log_den = np.log10(den_ov + 1)
peaks_idx, _ = find_peaks(log_den, height=1.0, prominence=0.3, width=1, distance=5)
print(f"Candidate peaks (GeV): {cen_ov[peaks_idx].round(2)}")

# ── Gaussian fit helper ───────────────────────────────────────────────────────
def gaussian(x, amp, mu, sigma):
    return amp * np.exp(-0.5 * ((x - mu) / sigma) ** 2)

def fit_region(M_all, lo, hi, n_bins, sig_lo, sig_hi, label):
    """Fit a Gaussian to the invariant mass distribution inside [lo, hi]."""
    bins = np.linspace(lo, hi, n_bins)
    cnt, edg = np.histogram(M_all, bins=bins)
    cen = 0.5 * (edg[:-1] + edg[1:])
    bw  = edg[1] - edg[0]
    den = cnt / bw

    peak_idx = int(np.argmax(den))
    mu0, amp0 = cen[peak_idx], den[peak_idx]

    popt, pcov = curve_fit(
        gaussian, cen, den,
        p0=[amp0, mu0, (sig_lo + sig_hi) / 2],
        bounds=([0, lo, sig_lo], [amp0 * 3, hi, sig_hi]),
        maxfev=10000,
    )
    perr = np.sqrt(np.diag(pcov))
    print(f"  {label}: μ={popt[1]:.4f}±{perr[1]:.4f} GeV  σ={popt[2]:.4f} GeV")
    return popt, cen, den

# Fit J/ψ region: 2.7–3.6 GeV (90 bins → 0.01 GeV/bin)
popt_jp, cen_jp, den_jp = fit_region(M, 2.7, 3.6, 90, 0.05, 0.50, "J/psi")

# Fit Z boson region: 85–97 GeV (120 bins → 0.1 GeV/bin)
popt_z,  cen_z,  den_z  = fit_region(M, 85,  97,  120, 1.0,  6.0,  "Z boson")

# ── Peak-fits figure ──────────────────────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(14, 5))

# J/ψ panel
axes[0].bar(cen_jp, den_jp, width=cen_jp[1] - cen_jp[0],
            color="steelblue", alpha=0.6, label="Data")
x_jp = np.linspace(2.7, 3.6, 500)
axes[0].plot(x_jp, gaussian(x_jp, *popt_jp), "r-", linewidth=2,
             label=f"J/ψ fit: {popt_jp[1]:.2f} GeV (σ={popt_jp[2]:.2f})")
axes[0].set_xlabel("M (GeV)")
axes[0].set_ylabel("Events / GeV")
axes[0].set_title("J/ψ Region (2.7–3.6 GeV)")
axes[0].legend()

# Z boson panel
axes[1].bar(cen_z, den_z, width=cen_z[1] - cen_z[0],
            color="steelblue", alpha=0.6, label="Data")
x_z = np.linspace(85, 97, 500)
axes[1].plot(x_z, gaussian(x_z, *popt_z), "r-", linewidth=2,
             label=f"Z fit: {popt_z[1]:.2f} GeV (σ={popt_z[2]:.2f})")
axes[1].set_xlabel("M (GeV)")
axes[1].set_ylabel("Events / GeV")
axes[1].set_title("Z Boson Region (85–97 GeV)")
axes[1].legend()

plt.tight_layout()
plt.savefig("/output/plots/peak_fits.png", dpi=100)
plt.close()
print("Saved peak_fits.png")

# ── Results ───────────────────────────────────────────────────────────────────
fitted_peaks = [
    {
        "position_gev": round(float(popt_jp[1]), 2),
        "width_gev":    round(float(popt_jp[2]), 2),
        "particle":     "J/psi",
    },
    {
        "position_gev": round(float(popt_z[1]), 2),
        "width_gev":    round(float(popt_z[2]), 2),
        "particle":     "Z boson",
    },
]

results = {
    "peaks":              fitted_peaks,
    "n_peaks_identified": len(fitted_peaks),
    "z_boson_peak_gev":   round(float(popt_z[1]),  2),
    "jpsi_peak_gev":      round(float(popt_jp[1]), 2),
}
with open("/output/results.json", "w") as f:
    json.dump(results, f, indent=2)

print(f"\nDone. J/ψ={results['jpsi_peak_gev']} GeV  Z={results['z_boson_peak_gev']} GeV")
