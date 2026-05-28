## Question
Given radial velocity observations of the star V723 Mon with timestamps in
Barycentric Julian Date (BJD), recover the orbital period of the binary system.
The observations are clustered in ~30-day windows once per year, creating strong
window-function aliases that dominate the naive Lomb-Scargle periodogram.

## Reasoning
This is an unevenly sampled time series with a trap: alias confusion.
1. Plot RV vs BJD — note the seasonal clustering (~30d observed per year)
2. Use Lomb-Scargle periodogram (not FFT — uneven sampling)
3. Naive LS top peak: ~71.8d with power=0.974 — this is the 1-year alias
   f_alias = f_true − 1/365.25 → 1/(1/59.9365 − 1/365.25) ≈ 71.7d
4. Phase-fold at 71.8d → chi²/dof ≈ 300 (terrible: not sinusoidal)
5. Also check 51.4d alias → equally bad chi²
6. Must scan chi² across all periods (or use fine-grid LS + phase-fold validation)
7. At P=59.9d the phase-folded curve is clean sinusoid: chi²/dof ≈ 0.9
8. The 30d annual window creates a strong 1-year component in the spectral window
   function, which aliases the true 59.94d signal into fake peaks at 71.7d and 51.5d
9. A naive analyst reports 71.8d; a correct analyst identifies 59.9d

## Answer
```json
{
  "period_days": 59.94,
  "amplitude_km_s": 65.3,
  "systemic_velocity_km_s": 1.6,
  "method": "Lomb-Scargle + chi2 phase-fold scan"
}
```
