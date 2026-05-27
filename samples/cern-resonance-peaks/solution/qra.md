## Question
Given 100,000 CERN dielectron collision events with kinematic features and
invariant mass M in GeV, analyze the invariant mass distribution and identify
any significant structures or features in the spectrum.

## Reasoning
This is a physics-informed spectral analysis task — not a regression problem:
1. Start with EDA — plot the raw invariant mass distribution as a histogram
2. Recognize the distribution is highly non-uniform with sharp spikes
3. Apply log scale to the y-axis to reveal smaller peaks hidden by the
   dominant Z boson peak
4. Use peak detection on the histogram counts to locate candidate peaks
5. Fit a Gaussian to each candidate peak to extract precise position and width
6. Identify peaks by comparing positions to known particle masses:
   - J/psi meson at ~3.1 GeV
   - Z boson at ~91.2 GeV
7. Report peak positions with uncertainty from the Gaussian fit
8. A naive regression model or summary statistics completely miss this —
   the structure only becomes visible through careful visualization and
   spectral analysis

## Answer
```json
{
  "peaks": [
    {
      "position_gev": 3.1,
      "width_gev": 0.1,
      "particle": "J/psi"
    },
    {
      "position_gev": 91.2,
      "width_gev": 2.5,
      "particle": "Z boson"
    }
  ],
  "n_peaks_identified": 2,
  "z_boson_peak_gev": 91.2,
  "jpsi_peak_gev": 3.1
}
```
