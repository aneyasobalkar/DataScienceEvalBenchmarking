import json
import os
import numpy as np
import pandas as pd
from scipy.optimize import curve_fit
from astropy.timeseries import LombScargle
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

os.makedirs('/output/plots', exist_ok=True)

df = pd.read_csv('/data/v723rv.csv')
df.columns = ['bjd', 'rv', 'rv_err']

t = df['bjd'].values
rv = df['rv'].values
rv_err = df['rv_err'].values

# --- Plot 1: RV vs BJD ---
fig, ax = plt.subplots(figsize=(12, 4))
ax.errorbar(t, rv, yerr=rv_err, fmt='o', ms=4, capsize=3, color='steelblue')
ax.set_xlabel('BJD')
ax.set_ylabel('RV (km/s)')
ax.set_title('V723 Mon Radial Velocity vs Time')
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('/output/plots/rv_vs_bjd.png', dpi=100)
plt.close()

# --- Lomb-Scargle periodogram ---
freq_min = 1.0 / 200.0
freq_max = 1.0 / 1.0
ls = LombScargle(t, rv, rv_err)
frequency, power = ls.autopower(minimum_frequency=freq_min,
                                 maximum_frequency=freq_max,
                                 samples_per_peak=50)
periods = 1.0 / frequency
best_freq = frequency[np.argmax(power)]
best_period = 1.0 / best_freq

# --- Plot 2: Lomb-Scargle periodogram ---
fig, ax = plt.subplots(figsize=(10, 4))
ax.plot(periods, power, color='darkred', lw=0.8)
ax.axvline(best_period, color='orange', linestyle='--', label=f'Peak: {best_period:.2f} d')
ax.set_xlabel('Period (days)')
ax.set_ylabel('Lomb-Scargle Power')
ax.set_title('Lomb-Scargle Periodogram')
ax.set_xscale('log')
ax.legend()
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('/output/plots/periodogram.png', dpi=100)
plt.close()

# --- Phase-fold ---
phase = ((t - t[0]) / best_period) % 1.0
sort_idx = np.argsort(phase)
phase_sorted = phase[sort_idx]
rv_sorted = rv[sort_idx]
rv_err_sorted = rv_err[sort_idx]

# --- Plot 3: Phase-folded RV ---
fig, ax = plt.subplots(figsize=(8, 4))
ax.errorbar(phase_sorted, rv_sorted, yerr=rv_err_sorted, fmt='o', ms=4,
            capsize=3, color='steelblue')
ax.set_xlabel('Phase')
ax.set_ylabel('RV (km/s)')
ax.set_title(f'Phase-folded RV (P = {best_period:.2f} d)')
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('/output/plots/phase_folded.png', dpi=100)
plt.close()

# --- Plot 4: Error distribution ---
fig, ax = plt.subplots(figsize=(6, 4))
ax.hist(rv_err, bins=20, color='steelblue', edgecolor='white')
ax.set_xlabel('RV Error (km/s)')
ax.set_ylabel('Count')
ax.set_title('Measurement Error Distribution')
ax.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('/output/plots/error_distribution.png', dpi=100)
plt.close()

# --- Sinusoid fit ---
def sinusoid(phase, amplitude, phase_offset, systemic):
    return amplitude * np.sin(2 * np.pi * phase + phase_offset) + systemic

p0 = [65.0, 0.0, 0.0]
try:
    popt, _ = curve_fit(sinusoid, phase_sorted, rv_sorted,
                        sigma=rv_err_sorted, p0=p0, maxfev=10000)
    amplitude = abs(popt[0])
    systemic = popt[2]
except Exception:
    amplitude = np.max(rv) - np.mean(rv)
    systemic = np.mean(rv)

results = {
    'period_days': round(float(best_period), 2),
    'amplitude_km_s': round(float(amplitude), 2),
    'systemic_velocity_km_s': round(float(systemic), 2)
}

print(f"Period:    {results['period_days']} days")
print(f"Amplitude: {results['amplitude_km_s']} km/s")
print(f"Systemic:  {results['systemic_velocity_km_s']} km/s")

with open('/output/results.json', 'w') as f:
    json.dump(results, f, indent=2)
