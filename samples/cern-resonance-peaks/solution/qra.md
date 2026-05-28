## Question
Given CERN dielectron collision events with kinematic features and invariant
mass M in GeV, analyze the invariant mass distribution and identify ALL
significant structures in the spectrum, including weaker peaks in the 9–10 GeV
Upsilon meson region.

## Reasoning
This is a physics-informed spectral analysis task — not a regression problem:
1. Start with EDA — plot the raw invariant mass distribution as a histogram
2. Recognize the distribution is highly non-uniform with sharp spikes
3. Apply log scale to the y-axis to reveal smaller peaks hidden by the
   dominant Z boson peak
4. Use peak detection on the histogram counts to locate candidate peaks;
   the Upsilon peaks at ~9.46 and ~10.02 GeV are much weaker than J/ψ and Z
5. Fit a Gaussian to each candidate peak to extract precise position and width
6. Identify peaks by comparing positions to known particle masses:
   - J/ψ meson at ~3.1 GeV
   - Υ(1S) at ~9.46 GeV and Υ(2S) at ~10.02 GeV (Upsilon mesons)
   - Z boson at ~91.2 GeV
7. Log scale is essential — without it the Upsilon peaks are invisible
8. A naive analysis that only looks for the largest peak (Z boson) misses
   the Upsilon region entirely

## Answer
```json
{
  "peaks": [
    {"position_gev": 3.1,  "width_gev": 0.10, "particle": "J/psi"},
    {"position_gev": 9.46, "width_gev": 0.15, "particle": "Upsilon(1S)"},
    {"position_gev": 10.02,"width_gev": 0.12, "particle": "Upsilon(2S)"},
    {"position_gev": 91.2, "width_gev": 2.5,  "particle": "Z boson"}
  ],
  "n_peaks_identified": 4,
  "z_boson_peak_gev": 91.2,
  "jpsi_peak_gev": 3.1,
  "upsilon_peak_gev": 9.46
}
```
