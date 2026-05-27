You are a data scientist analyzing stellar radial velocity observations.

## Dataset

The file `/data/v723rv.csv` contains radial velocity measurements of the star V723 Mon, a compact object binary system. The columns are:

- `bjd` — Barycentric Julian Date (timestamp of observation)
- `rv_km/s` — Radial velocity measurement in km/s
- `ðrv_km/s` — Measurement uncertainty (1-sigma error) in km/s

The data is unevenly sampled — observations were taken on different nights over several years with large gaps. There are 88 observations in total.

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
- Identify the period corresponding to the highest power peak

### Step 3 — Phase-fold and fit a sinusoid
- Fold the data on the recovered period
- Fit a sinusoid of the form: `A * sin(2π * phase + φ) + v_sys`
- Extract amplitude A and systemic velocity v_sys from the fit

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
