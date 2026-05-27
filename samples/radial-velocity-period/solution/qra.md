## Question
Given radial velocity observations of the star V723 Mon with timestamps in
Barycentric Julian Date (BJD), recover the orbital period of the binary system.
Each observation has a BJD timestamp, phase, radial velocity in km/s, and
measurement error.

## Reasoning
This is an unevenly sampled time series problem:
1. Plot RV vs BJD to understand the baseline and identify gaps
2. Use Lomb-Scargle periodogram which handles uneven sampling correctly —
   standard FFT assumes uniform sampling and will produce aliased results
3. Search periods between 1-200 days — physical constraints rule out very
   short or very long periods
4. Identify the peak in the periodogram as the candidate period
5. Phase-fold the data using the candidate period and verify a clean
   sinusoidal curve
6. Fit a sinusoid to extract amplitude and systemic velocity
7. Check for alias periods caused by the ~400 day observational gap

## Answer
```json
{
  "period_days": 59.9,
  "amplitude_km_s": 65.0,
  "systemic_velocity_km_s": 0.5,
  "method": "Lomb-Scargle periodogram"
}
```
