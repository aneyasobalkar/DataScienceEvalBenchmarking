#!/bin/bash
set -Eeuo pipefail

echo "=== Simpson's Paradox Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"paradox_detected_check":0,"correct_conclusion_check":0,"primary_confounder_check":0,"secondary_confounder_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
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
    out = {"paradox_detected_check":0,"correct_conclusion_check":0,
           "primary_confounder_check":0,"secondary_confounder_check":0,
           "Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(f"results.json parse error: {e}")
    sys.exit(1)

paradox_detected = results.get("paradox_detected", False)
correct_conclusion = str(results.get("correct_conclusion", "")).strip().lower()

# Accept single string or list for confounding variables
raw_confounders = results.get("confounding_variables",
                  results.get("confounding_variable", ""))
if isinstance(raw_confounders, list):
    confounder_list = [str(c).strip().lower() for c in raw_confounders]
else:
    confounder_list = [str(raw_confounders).strip().lower()]

paradox_check    = bool(paradox_detected is True or paradox_detected == "true")
conclusion_check = bool(correct_conclusion == "treatment is harmful")
primary_check    = bool("age_group" in confounder_list)
secondary_check  = bool("severity" in confounder_list)

print(f"Paradox detected:       {paradox_detected}  ->  {'PASS' if paradox_check else 'FAIL'} (need true)")
print(f"Correct conclusion:     {correct_conclusion!r}  ->  {'PASS' if conclusion_check else 'FAIL'} (need 'treatment is harmful')")
print(f"Primary confounder:     {confounder_list}  ->  {'PASS' if primary_check else 'FAIL'} (need 'age_group')")
print(f"Secondary confounder:   {confounder_list}  ->  {'PASS' if secondary_check else 'FAIL'} (need 'severity')")

det_pass = int(paradox_check and conclusion_check and primary_check and secondary_check)

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
                "You are evaluating a data science agent on a clinical trial analysis task. "
                "The dataset contains a NESTED Simpson's Paradox. Treatment looks beneficial overall. "
                "Stratifying by age_group alone is insufficient — young patients appear to benefit "
                "at the age_group level (86.6% vs 66.1% recovery), so agents must also stratify by "
                "severity to see that treatment is harmful in EVERY age×severity stratum. "
                "Score the agent on three dimensions, each 0-1:\n\n"
                "QRA Reference:\n\n"
                "## Reasoning\n"
                "1. Overall: trt=60.0% vs ctrl=44.9% — treatment looks beneficial\n"
                "2. Per age_group: young=BETTER (86.6% vs 66.1%), middle=WORSE, old=WORSE\n"
                "   → age_group alone is insufficient — young sub-paradox remains\n"
                "3. Both age_group AND severity must be controlled\n"
                "4. Per age×severity: ALL strata show treatment is WORSE (harmful)\n"
                "   young+mild: 90.2% vs 94.3%, young+severe: 42.2% vs 55.8%, etc.\n"
                "5. The nested confounding: young mild patients are 80% treated AND have high "
                "natural recovery — their high rate inflates the young stratum\n"
                "6. A naive analyst reports overall=positive. A partially-correct analyst reports "
                "age_group confounds but misses severity. Full credit requires BOTH confounders.\n\n"
                "## Answer\n"
                '{"overall_treatment_effect": "positive", '
                '"stratified_treatment_effect": "negative in all age×severity subgroups", '
                '"confounding_variables": ["age_group", "severity"], '
                '"correct_conclusion": "treatment is harmful", '
                '"paradox_detected": true}\n\n'
                "1. Sreason (weight 0.3): Did the agent identify that age_group alone is insufficient? "
                "Did it discover that severity is a SECOND confounder? Did it find that young patients "
                "only appear to benefit because mild cases are preferentially treated?\n\n"
                "2. Scode (weight 0.3): Does the code stratify by age×severity? Does it compute "
                "recovery rates in all 6 strata? Are visualizations produced showing the nested paradox?\n\n"
                "3. Sresult (weight 0.4): Did the agent report BOTH confounders (age_group AND "
                "severity)? Did it correctly conclude treatment is harmful? Agents that only identify "
                "age_group without severity score at most 0.5 on this dimension.\n\n"
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
    "paradox_detected_check":    int(paradox_check),
    "correct_conclusion_check":   int(conclusion_check),
    "primary_confounder_check":   int(primary_check),
    "secondary_confounder_check": int(secondary_check),
    "Sreason":                    Sreason,
    "Scode":                     Scode,
    "Sresult":                   Sresult,
    "weighted_score":            weighted_score,
    "reward":                    reward,
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
