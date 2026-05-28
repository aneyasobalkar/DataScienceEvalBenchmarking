#!/bin/bash
set -Eeuo pipefail

echo "=== A/B Test Violations Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"srm_check":0,"early_stopping_check":0,"multiple_testing_check":0,"recommendation_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
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
    out = {"srm_check":0,"recommendation_check":0,"multiple_testing_check":0,
           "Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(str(e))
    sys.exit(1)

srm_detected           = results.get("srm_detected", False)
recommendation             = str(results.get("recommendation", "")).strip().lower()
multiple_testing_violation = results.get("multiple_testing_violation", False)
early_stopping_detected    = results.get("early_stopping_detected", False)

srm_check  = bool(srm_detected is True or srm_detected == "true")
rec_check  = bool(recommendation == "do not ship")
mt_check   = bool(multiple_testing_violation is True or multiple_testing_violation == "true")
es_check   = bool(early_stopping_detected is True or early_stopping_detected == "true")

print(f"SRM detected:              {srm_detected}  ->  {'PASS' if srm_check else 'FAIL'} (need true)")
print(f"Early stopping detected:   {early_stopping_detected}  ->  {'PASS' if es_check else 'FAIL'} (need true)")
print(f"Multiple testing violation:{multiple_testing_violation}  ->  {'PASS' if mt_check else 'FAIL'} (need true)")
print(f"Recommendation:            {recommendation!r}  ->  {'PASS' if rec_check else 'FAIL'} (need 'do not ship')")

det_pass = int(srm_check and rec_check and mt_check and es_check)

# ── Part 2: LLM-as-judge ─────────────────────────────────────────────────────
Sreason = 0.0; Scode = 0.0; Sresult = 0.0
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
                "You are evaluating a data science agent on an A/B test validity analysis task. "
                "The experiment has three baked-in violations: Sample Ratio Mismatch (SRM), "
                "early stopping risk, and multiple testing without Bonferroni correction. "
                "Score the agent on three dimensions, each 0-1:\n\n"
                "The reference solution approach is documented in the QRA pair for this task. "
                "Use the Reasoning section of the QRA as the benchmark for Sreason. "
                "Use the Answer section as the benchmark for Sresult. "
                "Alternative valid approaches that reach the correct answer should still receive full credit.\n\n"
                "QRA Reference:\n\n"
                "## Question\n"
                "An e-commerce company ran an A/B test on a new checkout flow. Analyze the experiment "
                "results and determine whether the new checkout flow should be shipped.\n\n"
                "## Reasoning\n"
                "This requires checking experiment validity before analyzing results:\n"
                "1. Check for Sample Ratio Mismatch — run chi-squared test on group sizes vs expected "
                "50/50 split. Control has 25,800 users, treatment has 24,200 — groups look "
                "roughly balanced but chi²=51.2 (p≈8e-13) reveals a real SRM\n"
                "2. Check for early stopping — plot cumulative p-value over time. The p-value first "
                "crosses 0.05 at day 10, indicating the experiment could have been stopped prematurely\n"
                "3. Check for multiple testing — 4 metrics tested. Without Bonferroni correction, "
                "primary metric p=0.0218 looks significant. After correction (α/4=0.0125), "
                "p=0.0218 > 0.0125 — not significant (Bonferroni p=0.0870)\n"
                "4. The SRM alone is sufficient to invalidate the experiment\n"
                "5. A naive analyst just runs a t-test, sees p<0.05, and recommends shipping — wrong\n\n"
                "## Answer\n"
                '{"srm_detected": true, "srm_pvalue": 8.34e-13, '
                '"early_stopping_detected": true, "multiple_testing_violation": true, '
                '"bonferroni_corrected_pvalue": 0.0870, "recommendation": "do not ship", '
                '"reason": "experiment invalid due to sample ratio mismatch"}\n\n'
                "1. Sreason (Reasoning Process, weight 0.3): Did the agent check experiment validity "
                "before analyzing metric results? Did it identify all three violations (SRM, early "
                "stopping, multiple testing)? Did it correctly conclude the SRM invalidates the experiment?\n\n"
                "2. Scode (Code Steps, weight 0.3): Did the agent run a chi-squared test for SRM? "
                "Did it compute cumulative p-values over time? Did it apply Bonferroni correction? "
                "Are the visualizations informative?\n\n"
                "3. Sresult (Final Result, weight 0.4): Did the agent correctly recommend 'do not ship'? "
                "Did it identify SRM as the primary reason? A naive agent that just does a t-test and "
                "recommends shipping should score very low on this dimension.\n\n"
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
            payload = {"contents": [{"parts": [{"text": judge_prompt}]}]}
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
binary_reward = reward
det_fraction  = round((int(srm_check) + int(es_check) + int(mt_check) + int(rec_check)) / 4, 4)
fractional_reward = round(min(weighted_score, 1.0), 4) if det_pass else round(det_fraction * 0.5, 4)
print(f"\nFinal reward: {reward}  fractional: {fractional_reward}")

out = {
    "srm_check":              int(srm_check),
    "early_stopping_check":   int(es_check),
    "multiple_testing_check": int(mt_check),
    "recommendation_check":   int(rec_check),
    "Sreason":                Sreason,
    "Scode":                  Scode,
    "Sresult":                Sresult,
    "weighted_score":         weighted_score,
    "reward":                 reward,
    "binary_reward":          binary_reward,
    "fractional_reward":      fractional_reward,
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
