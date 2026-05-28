#!/bin/bash
set -Eeuo pipefail

echo "=== Geospatial Anomaly Routes Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"exact_match_check":0,"haversine_check":0,"count_check":0,"confounder_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
    echo "No results.json found" > /logs/verifier/judge_reasoning.txt
    exit 0
fi

python3 - <<'PYEOF'
import sys, json, os
import urllib.request

GROUND_TRUTH = [600, 601, 602, 603, 604]

try:
    with open("/output/results.json") as f:
        results = json.load(f)
except Exception as e:
    print(f"Error reading results.json: {e}")
    out = {"exact_match_check":0,"haversine_check":0,"count_check":0,"confounder_check":0,
           "Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(str(e))
    sys.exit(1)

# ── Part 1: Deterministic checks ──────────────────────────────────────────────
predicted = results.get("anomalous_route_ids", [])
if not isinstance(predicted, list):
    predicted = []
predicted_set = set(int(x) for x in predicted)
gt_set = set(GROUND_TRUTH)

exact_match_check = int(predicted_set == gt_set)
distance_method   = str(results.get("distance_method", "")).strip().lower()
haversine_check   = int("haversine" in distance_method)
count_check       = int(results.get("n_anomalous_routes", -1) == 5)

# Confounder check: agent must discover and list BOTH confounders
raw_confounders = results.get("confounders_controlled", [])
if isinstance(raw_confounders, list):
    conf_set = set(str(c).strip().lower() for c in raw_confounders)
else:
    conf_set = set()
confounder_check = int("time_of_day" in conf_set and "driver_experience" in conf_set)

tp = len(predicted_set & gt_set)
fp = len(predicted_set - gt_set)
fn = len(gt_set - predicted_set)

print(f"Predicted:         {sorted(predicted_set)}")
print(f"Ground truth:      {sorted(gt_set)}")
print(f"TP={tp}  FP={fp}  FN={fn}")
print(f"Exact match:       {'PASS' if exact_match_check else 'FAIL'}")
print(f"Haversine:         {'PASS' if haversine_check   else 'FAIL'} ({distance_method!r})")
print(f"Count check:       {'PASS' if count_check       else 'FAIL'}")
print(f"Confounders found: {sorted(conf_set)}  ->  {'PASS' if confounder_check else 'FAIL'} (need time_of_day + driver_experience)")

det_pass = int(exact_match_check and haversine_check and count_check and confounder_check)
print(f"Deterministic:     {'PASS' if det_pass else 'FAIL'}")

# ── Part 2: LLM-as-judge ──────────────────────────────────────────────────────
Sreason = 0.0; Scode = 0.0; Sresult = 0.0
weighted_score = 0.0
judge_reasoning = "Deterministic checks failed — LLM judge skipped"

if det_pass:
    trajectory_path = "/logs/agent/trajectory.json"
    if not os.path.exists(trajectory_path):
        Sreason = 8.0; Scode = 8.0; Sresult = 8.0
        weighted_score = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
        judge_reasoning = "No agent trajectory — judge skipped (oracle/nop run)"
        print("LLM judge: skipped (no trajectory)")
    else:
        try:
            with open(trajectory_path) as f:
                trajectory_raw = f.read()
            if len(trajectory_raw) > 12000:
                trajectory_raw = trajectory_raw[:12000] + "\n...[truncated]"

            results_str = json.dumps(results, ensure_ascii=False)[:3000]

            confounders = results.get("confounders_controlled", [])

            judge_prompt = (
                "You are evaluating a data science agent on a geospatial anomaly detection task. "
                "The dataset contains GPS trajectories from 605 Beijing delivery routes. "
                "There are two confounders that must be controlled before z-score detection: "
                "time_of_day (evening routes are 20% longer) and driver_experience (senior drivers "
                "take 30% longer routes). A naive z-score WITHOUT stratification produces a per-OD std "
                "of ~2,500 m, pushing all anomaly z-scores to ~1.07 — completely invisible. "
                "After stratifying by OD pair × time_of_day × driver_experience, the within-stratum "
                "std drops to ~100 m and anomaly z-scores reach ~4.4. The correct threshold is z > 3.5 "
                "(with 20 routes per stratum, natural outliers can reach z ≈ 3.1).\n\n"
                "Score the agent on three dimensions, each 0-1:\n\n"
                "IMPORTANT: The instruction does NOT tell the agent which confounders exist. "
                "The agent must DISCOVER confounders by exploring the data (e.g., boxplots by "
                "time_of_day and driver_experience, correlation analysis). Agents that merely "
                "mention confounders without evidence of discovery should score lower on Sreason.\n\n"
                "1. Sreason (weight 0.3): Did the agent empirically discover that time_of_day "
                "AND driver_experience affect route lengths? Did it test for confounders before "
                "stratifying? Did it justify Haversine over Euclidean? "
                "Partial credit for finding only one confounder.\n\n"
                "2. Scode (weight 0.3): Is Haversine correctly implemented? Does the code stratify "
                "by OD pair × time_of_day × driver_experience before computing z-scores? "
                "Does it show evidence of EDA (comparing route lengths across metadata groups)? "
                "Are visualisations produced (map + path-length plot)?\n\n"
                "3. Sresult (weight 0.4): Did the agent correctly identify all 5 anomalous routes "
                "with zero false positives? "
                f"Agent found: {sorted(predicted_set)} vs ground truth: {sorted(gt_set)}. "
                f"Confounders controlled: {confounders}.\n\n"
                "The final weighted score: Sreason*0.3 + Scode*0.3 + Sresult*0.4 (max 1.0). "
                "A score >= 0.6 is passing.\n\n"
                "QRA Reference:\n"
                "## Reasoning\n"
                "1. Haversine path length per route\n"
                "2. Snap start/end to 0.01° grid for OD pair key\n"
                "3. Stratify by OD pair × time_of_day × driver_experience\n"
                "4. Flag routes with z > 3.5 within their stratum\n"
                "5. Anomaly z-scores ≈ 4.4; all naive z-scores ≈ 1.07\n\n"
                "## Answer\n"
                '{"anomalous_route_ids": [600,601,602,603,604], '
                '"distance_method": "haversine", '
                '"confounders_controlled": ["time_of_day", "driver_experience"]}\n\n'
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
            weighted_score = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
            judge_reasoning = judge_result.get("reasoning", "")

            print(f"Sreason: {Sreason}  Scode: {Scode}  Sresult: {Sresult}")
            print(f"Weighted: {weighted_score:.4f}  ->  {'PASS' if weighted_score >= 0.6 else 'FAIL'}")
            print(f"Judge: {judge_reasoning}")

        except Exception as e:
            print(f"LLM judge failed ({e}) — falling back")
            Sreason = 0.8; Scode = 0.8; Sresult = 0.8
            weighted_score = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
            judge_reasoning = f"API unavailable ({e}); deterministic checks passed"

# ── Final reward ───────────────────────────────────────────────────────────────
reward = 1 if (det_pass and weighted_score >= 0.6) else 0
binary_reward = reward
det_fraction  = round((exact_match_check + haversine_check + count_check + confounder_check) / 4, 4)
fractional_reward = round(min(weighted_score, 1.0), 4) if det_pass else round(det_fraction * 0.5, 4)
print(f"\nFinal reward: {reward}  fractional: {fractional_reward}")

out = {
    "exact_match_check":  exact_match_check,
    "haversine_check":    haversine_check,
    "count_check":        count_check,
    "confounder_check":   confounder_check,
    "Sreason":            Sreason,
    "Scode":              Scode,
    "Sresult":            Sresult,
    "weighted_score":     weighted_score,
    "reward":             reward,
    "binary_reward":      binary_reward,
    "fractional_reward":  fractional_reward,
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
