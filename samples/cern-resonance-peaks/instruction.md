# CERN Dielectron Collision Analysis

You are a data scientist analyzing particle physics collision data from the CMS detector at CERN.

## Dataset

The dataset contains dielectron collision events. Each row is a single collision event with kinematic measurements for two electrons:

- `E1`, `E2` — energy of each electron (GeV)
- `px1`, `px2`, `py1`, `py2`, `pz1`, `pz2` — momentum components (GeV/c)
- `pt1`, `pt2` — transverse momentum (GeV/c)
- `eta1`, `eta2` — pseudorapidity
- `phi1`, `phi2` — azimuthal angle (radians)
- `Q1`, `Q2` — electric charge
- `M` — invariant mass of the dielectron pair (GeV)

Data is at `/data/dielectron.csv`.

## Your Task

Analyze the invariant mass distribution and identify any significant features or structures in the spectrum.

1. **Explore the data** — understand the distribution of the invariant mass column `M`.

2. **Visualize** — produce informative plots of the mass spectrum. Save all visualizations to `/output/plots/`.

3. **Identify structures** — locate and characterize any significant features you find.

4. **Quantify** — for each significant feature, extract its position and width precisely.

5. **Write results** to `/output/results.json`:
```json
{
  "peaks": [
    {
      "position_gev": <float, 2 decimal places>,
      "width_gev": <float, 2 decimal places>,
      "particle": "<name or 'unknown'>"
    }
  ],
  "n_peaks_identified": <int>,
  "z_boson_peak_gev": <float or null>,
  "jpsi_peak_gev": <float or null>,
  "upsilon_peak_gev": <float or null>
}
```

## Constraints

- Lightweight methods only — no neural networks or deep learning
- All plots must be saved to `/output/plots/` before writing `results.json`
