#!/bin/bash
set -Eeuo pipefail

echo "=== Radial Velocity Period Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"period_check":0,"amplitude_check":0,"systemic_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
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
    out = {"period_check":0,"amplitude_check":0,"systemic_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(f"results.json parse error: {e}")
    sys.exit(1)

period    = float(results.get("period_days",              -999))
amplitude = float(results.get("amplitude_km_s",           -999))
systemic  = float(results.get("systemic_velocity_km_s",   -999))

period_check   = bool(abs(period    - 59.9) <= 0.5)
amplitude_check = bool(abs(amplitude - 65.0) <= 5.0)
systemic_check  = bool(abs(systemic  - 0.5)  <= 3.0)

print(f"Period:    {period:.2f} d     ->  {'PASS' if period_check   else 'FAIL'} (need 59.9 ± 0.5)")
print(f"Amplitude: {amplitude:.2f} km/s ->  {'PASS' if amplitude_check else 'FAIL'} (need 65.0 ± 5.0)")
print(f"Systemic:  {systemic:.2f} km/s  ->  {'PASS' if systemic_check  else 'FAIL'} (need 0.5 ± 3.0)")

det_pass = int(period_check and amplitude_check and systemic_check)

# ── Part 2: LLM-as-judge (only if deterministic checks pass) ─────────────────
Sreason = 0.0
Scode   = 0.0
Sresult = 0.0
weighted_score  = 0.0
judge_reasoning = "Deterministic checks failed — LLM judge skipped"

if det_pass:
    trajectory_path = "/logs/agent/trajectory.json"

    if not os.path.exists(trajectory_path):
        Sreason = 8.0; Scode = 8.0; Sresult = 8.0
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
                "You are evaluating a data science agent on a radial velocity period recovery task. "
                "The agent was given unevenly sampled radial velocity observations of a binary star "
                "and must recover the orbital period. Score the agent on three dimensions, each 0-10:\n\n"
                "The reference solution approach is documented in the QRA pair for this task. "
                "Use the Reasoning section of the QRA as the benchmark for Sreason — if the "
                "agent followed a similar methodology it should score highly. Use the Answer "
                "section as the benchmark for Sresult — if the agent's output matches the "
                "expected structure and values it should score highly. Alternative valid "
                "approaches that reach the correct answer should still receive full credit.\n\n"
                "QRA Reference:\n\n"
                "## Question\n"
                "Given radial velocity observations of the star V723 Mon with timestamps in "
                "Barycentric Julian Date (BJD), recover the orbital period of the binary system. "
                "Each observation has a BJD timestamp, phase, radial velocity in km/s, and "
                "measurement error.\n\n"
                "## Reasoning\n"
                "This is an unevenly sampled time series problem:\n"
                "1. Plot RV vs BJD to understand the baseline and identify gaps\n"
                "2. Use Lomb-Scargle periodogram which handles uneven sampling correctly — "
                "standard FFT assumes uniform sampling and will produce aliased results\n"
                "3. Search periods between 1-200 days — physical constraints rule out very "
                "short or very long periods\n"
                "4. Identify the peak in the periodogram as the candidate period\n"
                "5. Phase-fold the data using the candidate period and verify a clean "
                "sinusoidal curve\n"
                "6. Fit a sinusoid to extract amplitude and systemic velocity\n"
                "7. Check for alias periods caused by the ~400 day observational gap\n\n"
                "## Answer\n"
                '{"period_days": 59.9, "amplitude_km_s": 65.0, '
                '"systemic_velocity_km_s": 0.5, "method": "Lomb-Scargle periodogram"}\n\n'
                "1. Sreason (Reasoning Process, weight 0.3): Did the agent recognise this is an "
                "unevenly sampled time series problem? Did it use Lomb-Scargle or an equivalent "
                "method suited to irregular sampling rather than standard FFT? Did it phase-fold "
                "to verify the period?\n\n"
                "2. Scode (Code Steps, weight 0.3): Is the code logically coherent? Does it "
                "correctly implement periodogram analysis, phase-folding, and sinusoidal fitting? "
                "Does it produce meaningful intermediate plots?\n\n"
                "3. Sresult (Final Result, weight 0.4): Are the recovered period, amplitude, and "
                "systemic velocity physically reasonable? Are the visualizations informative? "
                "Accept valid alternative period-finding approaches.\n\n"
                "The final weighted score will be: Sreason*0.3 + Scode*0.3 + Sresult*0.4 (max 10.0). "
                "A score of 6.0 or above is considered passing.\n\n"
                f"Agent trajectory:\n{trajectory_raw}\n\n"
                f"Agent results:\n{results_str}\n\n"
                "Respond with JSON only, no other text:\n"
                '{"Sreason": <0-10>, "Scode": <0-10>, "Sresult": <0-10>, "reasoning": "<two sentences>"}'
            )

            api_key = os.environ.get("GEMINI_API_KEY", "")
            if not api_key:
                raise ValueError("GEMINI_API_KEY not set")

            payload = {
                "model": "gemini/gemini-2.0-flash",
                "max_tokens": 1000,
                "messages": [{"role": "user", "content": judge_prompt}]
            }
            req = urllib.request.Request(
                "http://localhost:4000/v1/chat/completions",
                data=json.dumps(payload).encode(),
                headers={
                    "Content-Type":  "application/json",
                    "Authorization": f"Bearer {api_key}"
                }
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                response = json.loads(resp.read())

            judge_result = json.loads(response["choices"][0]["message"]["content"])
            Sreason = float(judge_result.get("Sreason", 0))
            Scode   = float(judge_result.get("Scode",   0))
            Sresult = float(judge_result.get("Sresult", 0))
            weighted_score  = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
            judge_reasoning = judge_result.get("reasoning", "")

            print(f"Sreason: {Sreason}  Scode: {Scode}  Sresult: {Sresult}")
            print(f"Weighted score: {weighted_score:.4f}  ->  {'PASS' if weighted_score >= 6.0 else 'FAIL'} (need >= 6.0)")
            print(f"Judge: {judge_reasoning}")

        except Exception as e:
            print(f"LLM judge failed ({e}) — falling back to deterministic-only")
            Sreason = 8.0; Scode = 8.0; Sresult = 8.0
            weighted_score  = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
            judge_reasoning = f"API unavailable ({e}); deterministic checks passed"

# ── Final reward ──────────────────────────────────────────────────────────────
reward = 1 if (det_pass and weighted_score >= 6.0) else 0
print(f"\nFinal reward: {reward}")

out = {
    "period_check":    int(period_check),
    "amplitude_check": int(amplitude_check),
    "systemic_check":  int(systemic_check),
    "Sreason":         Sreason,
    "Scode":           Scode,
    "Sresult":         Sresult,
    "weighted_score":  weighted_score,
    "reward":          reward,
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
