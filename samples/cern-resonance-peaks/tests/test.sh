#!/bin/bash
set -Eeuo pipefail

echo "=== CERN Resonance Peaks Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"z_boson_check":0,"jpsi_check":0,"n_peaks_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
    echo "No results.json found" > /logs/verifier/judge_reasoning.txt
    exit 0
fi

python3 - <<'PYEOF'
import sys, json, os
import urllib.request

# ── Part 1: Deterministic checks ─────────────────────────────────────────────
try:
    with open("/output/results.json") as f:
        results = json.load(f)
except Exception as e:
    print(f"Error reading results.json: {e}")
    out = {"z_boson_check":0,"jpsi_check":0,"n_peaks_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(f"results.json parse error: {e}")
    sys.exit(1)

z_gev  = results.get("z_boson_peak_gev")
jp_gev = results.get("jpsi_peak_gev")
n_pk   = int(results.get("n_peaks_identified", 0))

z_check  = bool(z_gev  is not None and abs(float(z_gev)  - 91.2) <= 2.0)
jp_check = bool(jp_gev is not None and abs(float(jp_gev) - 3.1)  <= 0.5)
n_check  = bool(n_pk >= 2)

print(f"Z boson peak:   {z_gev} GeV  ->  {'PASS' if z_check else 'FAIL'} (need 89.2–93.2)")
print(f"J/psi peak:     {jp_gev} GeV  ->  {'PASS' if jp_check else 'FAIL'} (need 2.6–3.6)")
print(f"Peaks found:    {n_pk}        ->  {'PASS' if n_check else 'FAIL'} (need >= 2)")

det_pass = int(z_check and jp_check and n_check)

# ── Part 2: LLM-as-judge (only if deterministic checks pass) ─────────────────
Sreason = 0.0
Scode   = 0.0
Sresult = 0.0
weighted_score  = 0.0
judge_reasoning = "Deterministic checks failed — LLM judge skipped"

if det_pass:
    trajectory_path = "/logs/agent/trajectory.json"

    if not os.path.exists(trajectory_path):
        Sreason = 0.8; Scode = 0.8; Sresult = 0.8
        weighted_score  = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
        judge_reasoning = "No agent trajectory — judge skipped (oracle/nop run)"
        print("LLM judge: skipped (no trajectory)")
    else:
        try:
            with open(trajectory_path) as f:
                trajectory_raw = f.read()
            if len(trajectory_raw) > 12000:
                trajectory_raw = trajectory_raw[:12000] + "\n...[truncated]"

            results_str = json.dumps(results, ensure_ascii=False)[:3000]

            judge_prompt = (
                "You are evaluating a data science agent on a CERN particle physics data analysis task. "
                "The agent was asked to analyze the invariant mass spectrum of dielectron collision events "
                "and identify significant structures. "
                "Score the agent on three dimensions, each 0-1:\n\n"
                "The reference solution approach is documented in the QRA pair for this task. "
                "Use the Reasoning section of the QRA as the benchmark for Sreason — if the "
                "agent followed a similar methodology it should score highly. Use the Answer "
                "section as the benchmark for Sresult — if the agent's output matches the "
                "expected structure and values it should score highly. Alternative valid "
                "approaches that reach the correct answer should still receive full credit.\n\n"
                "QRA Reference:\n\n"
                "## Question\n"
                "Given 100,000 CERN dielectron collision events with kinematic features and "
                "invariant mass M in GeV, analyze the invariant mass distribution and identify "
                "any significant structures or features in the spectrum.\n\n"
                "## Reasoning\n"
                "This is a physics-informed spectral analysis task — not a regression problem:\n"
                "1. Start with EDA — plot the raw invariant mass distribution as a histogram\n"
                "2. Recognize the distribution is highly non-uniform with sharp spikes\n"
                "3. Apply log scale to the y-axis to reveal smaller peaks hidden by the "
                "dominant Z boson peak\n"
                "4. Use peak detection on the histogram counts to locate candidate peaks\n"
                "5. Fit a Gaussian to each candidate peak to extract precise position and width\n"
                "6. Identify peaks by comparing positions to known particle masses: "
                "J/psi meson at ~3.1 GeV, Z boson at ~91.2 GeV\n"
                "7. Report peak positions with uncertainty from the Gaussian fit\n"
                "8. A naive regression model completely misses this — structure only becomes "
                "visible through careful visualization and spectral analysis\n\n"
                "## Answer\n"
                '{"peaks": [{"position_gev": 3.1, "width_gev": 0.1, "particle": "J/psi"}, '
                '{"position_gev": 91.2, "width_gev": 2.5, "particle": "Z boson"}], '
                '"n_peaks_identified": 2, "z_boson_peak_gev": 91.2, "jpsi_peak_gev": 3.1}\n\n'
                "1. Sreason (Reasoning Process, weight 0.3): Did the agent recognise this is a spectral "
                "analysis problem rather than a regression problem? Did it use appropriate visualization "
                "(log scale, histogram) to discover peaks? Is the methodology physically sound?\n\n"
                "2. Scode (Code Steps, weight 0.3): Is the code logically coherent? Does it correctly "
                "implement peak detection and Gaussian fitting? Does it produce meaningful intermediate "
                "outputs?\n\n"
                "3. Sresult (Final Result, weight 0.4): Did the agent correctly identify the resonance "
                "peaks? Are the peak positions physically reasonable (J/ψ ~3.1 GeV, Z ~91.2 GeV)? "
                "Are the visualizations informative? Accept valid alternative peak detection approaches.\n\n"
                "The final weighted score will be: Sreason*0.3 + Scode*0.3 + Sresult*0.4 (max 1.0). "
                "A score of 0.6 or above is considered passing.\n\n"
                f"Agent trajectory:\n{trajectory_raw}\n\n"
                f"Agent results:\n{results_str}\n\n"
                "Respond with JSON only, no other text:\n"
                '{"Sreason": <0-1>, "Scode": <0-1>, "Sresult": <0-1>, "reasoning": "<two sentences>"}'
            )

            api_key = os.environ.get("GEMINI_API_KEY", "")
            if not api_key:
                raise ValueError("GEMINI_API_KEY not set")

            url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
            payload = {
                "contents": [{
                    "parts": [{"text": judge_prompt}]
                }]
            }
            req = urllib.request.Request(
                f"{url}?key={api_key}",
                data=json.dumps(payload).encode(),
                headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                response = json.loads(resp.read())

            content = response["candidates"][0]["content"]["parts"][0]["text"]
            judge_result = json.loads(content)
            Sreason = float(judge_result.get("Sreason", 0))
            Scode   = float(judge_result.get("Scode",   0))
            Sresult = float(judge_result.get("Sresult", 0))
            weighted_score  = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
            judge_reasoning = judge_result.get("reasoning", "")

            print(f"Sreason: {Sreason}  Scode: {Scode}  Sresult: {Sresult}")
            print(f"Weighted score: {weighted_score:.4f}  ->  {'PASS' if weighted_score >= 0.6 else 'FAIL'} (need >= 0.6)")
            print(f"Judge: {judge_reasoning}")

        except Exception as e:
            print(f"LLM judge failed ({e}) — falling back to deterministic-only")
            Sreason = 0.8; Scode = 0.8; Sresult = 0.8
            weighted_score  = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
            judge_reasoning = f"API unavailable ({e}); deterministic checks passed"

# ── Final reward ──────────────────────────────────────────────────────────────
reward = 1 if (det_pass and weighted_score >= 0.6) else 0
print(f"\nFinal reward: {reward}")

out = {
    "z_boson_check":  int(z_check),
    "jpsi_check":     int(jp_check),
    "n_peaks_check":  int(n_check),
    "Sreason":        Sreason,
    "Scode":          Scode,
    "Sresult":        Sresult,
    "weighted_score": weighted_score,
    "reward":         reward,
}
with open("/logs/verifier/reward.json",        "w") as f: json.dump(out, f, indent=2)
with open("/logs/verifier/reward.txt",         "w") as f: f.write(str(reward))
with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(judge_reasoning)

sys.exit(0 if reward == 1 else 1)
PYEOF

exit_code=$?
if   [ $exit_code -eq 0 ]; then echo "All checks passed"
else                              echo "One or more checks failed"
fi
exit 0
