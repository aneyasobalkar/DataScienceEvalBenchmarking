You are a data scientist analyzing stellar radial velocity observations.

## Dataset

The file `/data/v723rv.csv` contains radial velocity measurements of the star V723 Mon, a compact object binary system. The columns are:

- `bjd` — Barycentric Julian Date (timestamp of observation)
- `rv_km/s` — Radial velocity measurement in km/s
- `ðrv_km/s` — Measurement uncertainty (1-sigma error) in km/s

The data is unevenly sampled — observations were clustered in short windows of approximately 30 days per year, with large seasonal gaps between seasons. There are 55 observations spanning 4 seasons.

## Your Task

Recover the orbital period of V723 Mon and characterize its radial velocity curve.

### Step 1 — Explore and visualize the data
Produce the following 4 plots and save them to `/output/plots/`:
1. `rv_vs_bjd.png` — RV vs BJD (raw time series with error bars)
2. `periodogram.png` — Lomb-Scargle periodogram (power vs period in days, log x-axis)
3. `phase_folded.png` — RV vs phase after folding on the recovered period
4. `error_distribution.png` — histogram of measurement uncertainties

### Step 2 — Run a Lomb-Scargle periodogram
Because the data is unevenly sampled, standard FFT will not work. You must use a Lomb-Scargle periodogram.

- Choose an appropriate period search range based on the data's time baseline and sampling
- Use measurement uncertainties as weights
- Note: the seasonal observation gaps create strong 1-year aliases — the highest power peak may not be the true orbital period

### Step 3 — Phase-fold and fit a sinusoid
- Fold the data on each significant candidate period and **check the quality of the fit**
- Fit a sinusoid of the form: `A * sin(2π * phase + φ) + v_sys`
- The true period should produce a significantly lower residual scatter (chi² or RMS) than alias periods
- Extract amplitude A and systemic velocity v_sys from the best-fitting period

### Step 4 — Write results
Write your results to `/output/results.json` in exactly this format:
```json
{
  "period_days": <float rounded to 2 decimal places>,
  "amplitude_km_s": <float rounded to 2 decimal places>,
  "systemic_velocity_km_s": <float rounded to 2 decimal places>
}
```

## Notes
- All plots must be saved to `/output/plots/` before writing results.json
- The strongest LS peak may be a window-function alias of the true period — always validate via phase-folding quality
- The true orbital period should yield a clean sinusoidal phase-folded curve with chi²/dof ≈ 1; aliases yield chi²/dof >> 1
