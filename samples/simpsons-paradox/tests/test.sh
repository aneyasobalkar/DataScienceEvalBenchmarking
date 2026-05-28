#!/bin/bash
set -Eeuo pipefail

echo "=== Simpson's Paradox Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"paradox_detected_check":0,"correct_conclusion_check":0,"confounding_variable_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
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
           "confounding_variable_check":0,"Sreason":0,"Scode":0,
           "Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(f"results.json parse error: {e}")
    sys.exit(1)

paradox_detected = results.get("paradox_detected", False)
correct_conclusion = str(results.get("correct_conclusion", "")).strip().lower()
confounding_variable = str(results.get("confounding_variable", "")).strip().lower()

paradox_check   = bool(paradox_detected is True or paradox_detected == "true")
conclusion_check = bool(correct_conclusion == "treatment is harmful")
confounder_check = bool(confounding_variable == "age_group")

print(f"Paradox detected:      {paradox_detected}  ->  {'PASS' if paradox_check else 'FAIL'} (need true)")
print(f"Correct conclusion:    {correct_conclusion!r}  ->  {'PASS' if conclusion_check else 'FAIL'} (need 'treatment is harmful')")
print(f"Confounding variable:  {confounding_variable!r}  ->  {'PASS' if confounder_check else 'FAIL'} (need 'age_group')")

det_pass = int(paradox_check and conclusion_check and confounder_check)

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
                "You are evaluating a data science agent on a clinical trial analysis task. "
                "The dataset contains a Simpson's Paradox where the treatment appears beneficial "
                "overall but is harmful in every age subgroup. "
                "Score the agent on three dimensions, each 0-10:\n\n"
                "The reference solution approach is documented in the QRA pair for this task. "
                "Use the Reasoning section of the QRA as the benchmark for Sreason — if the "
                "agent followed a similar methodology it should score highly. Use the Answer "
                "section as the benchmark for Sresult — if the agent's output matches the "
                "expected structure and values it should score highly. Alternative valid "
                "approaches that reach the correct answer should still receive full credit.\n\n"
                "QRA Reference:\n\n"
                "## Question\n"
                "A clinical trial dataset shows the overall effect of a treatment on patient "
                "recovery rates. Analyze the relationship between treatment and recovery, and "
                "determine whether the treatment is actually beneficial.\n\n"
                "## Reasoning\n"
                "This requires recognizing Simpson's Paradox:\n"
                "1. First compute overall recovery rate by treatment group — treatment appears "
                "beneficial overall (~52% vs ~42%)\n"
                "2. Recognize this alone is insufficient — check for confounding variables\n"
                "3. Stratify by every categorical variable in the dataset\n"
                "4. Find the subgroup where direction reverses — overall looks positive but "
                "treatment is worse within every age group\n"
                "5. Identify the confounding variable: age_group\n"
                "6. Mechanism: young patients (high natural recovery ~80%) were 69% treated "
                "while old patients (low recovery ~25%) were 80% controls — inflating the "
                "treatment arm's overall rate\n"
                "7. Report the CORRECT conclusion based on stratified analysis\n"
                "8. A naive analyst who only computes overall correlation reaches the wrong answer\n\n"
                "## Answer\n"
                '{"overall_treatment_effect": "positive", '
                '"stratified_treatment_effect": "negative in all subgroups", '
                '"confounding_variable": "age_group", '
                '"correct_conclusion": "treatment is harmful", '
                '"paradox_detected": true}\n\n'
                "1. Sreason (Reasoning Process, weight 0.3): Did the agent recognise that "
                "overall statistics can be misleading? Did it stratify by categorical variables? "
                "Did it identify age_group as the confounder and explain the mechanism?\n\n"
                "2. Scode (Code Steps, weight 0.3): Is the code logically coherent? Does it "
                "correctly compute stratified recovery rates per subgroup? Does it produce "
                "meaningful visualizations comparing overall vs stratified results?\n\n"
                "3. Sresult (Final Result, weight 0.4): Did the agent reach the correct conclusion "
                "that treatment is harmful? Did it correctly identify age_group as the confounding "
                "variable? Are the visualizations informative? A naive agent that reports only "
                "the overall positive effect without stratification should score very low.\n\n"
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
    "paradox_detected_check":    int(paradox_check),
    "correct_conclusion_check":  int(conclusion_check),
    "confounding_variable_check": int(confounder_check),
    "Sreason":                   Sreason,
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
