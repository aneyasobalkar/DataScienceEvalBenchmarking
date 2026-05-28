#!/bin/bash
set -Eeuo pipefail

echo "=== Geospatial Anomaly Synthetic Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"route_detection_check":0,"haversine_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
    echo "No results.json found" > /logs/verifier/judge_reasoning.txt
    exit 0
fi

python3 - <<'PYEOF'
import sys, json, os
import urllib.request

GROUND_TRUTH_IDS = [35,36,37,38,39,75,76,77,78,79,
                    115,116,117,118,119,155,156,157,158,159,
                    195,196,197,198,199]
N_GT = len(GROUND_TRUTH_IDS)

try:
    with open("/output/results.json") as f:
        results = json.load(f)
except Exception as e:
    print(f"Error reading results.json: {e}")
    out = {"route_detection_check":0,"haversine_check":0,
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
gt_set = set(GROUND_TRUTH_IDS)

# All ground truth IDs must be detected (recall = 1.0)
missing = gt_set - predicted_set
route_detection_check = int(len(missing) == 0)

# Agent must declare haversine as distance method
distance_method = str(results.get("distance_method", "")).strip().lower()
haversine_check = int("haversine" in distance_method)

n_detected = results.get("n_anomalous_routes", len(predicted_set))

print(f"Predicted IDs: {sorted(predicted_set)}")
print(f"Ground truth:  {sorted(gt_set)}")
print(f"Missing:       {sorted(missing)}")
print(f"False positives: {sorted(predicted_set - gt_set)}")
print(f"Route detection: {'PASS' if route_detection_check else 'FAIL'} (all {N_GT} GT IDs must be found)")
print(f"Haversine check: {'PASS' if haversine_check else 'FAIL'} (distance_method={distance_method!r})")

det_pass = int(route_detection_check and haversine_check)

# ── Part 2: LLM-as-judge ──────────────────────────────────────────────────────
Sreason = 0.0; Scode = 0.0; Sresult = 0.0
weighted_score = 0.0
judge_reasoning = "Deterministic checks failed — LLM judge skipped"

if det_pass:
    trajectory_path = "/logs/agent/trajectory.json"
    if not os.path.exists(trajectory_path):
        Sreason = 0.8; Scode = 0.8; Sresult = 0.8
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

            n_fp = len(predicted_set - gt_set)
            judge_prompt = (
                "You are evaluating a data science agent on a geospatial anomaly detection task. "
                "The agent must identify anomalous GPS delivery routes in San Francisco by using "
                "correct geospatial distance methods and comparing routes by origin-destination pair.\n\n"
                "Score the agent on three dimensions, each 0-1:\n\n"
                "QRA Reference:\n\n"
                "## Question\n"
                "Given GPS trajectory data from delivery drivers in San Francisco, identify which "
                "routes are anomalous — taking significantly longer paths than expected between the "
                "same origin-destination pairs.\n\n"
                "## Reasoning\n"
                "1. Load trajectories.csv (7,158 rows, 200 routes with 20-50 GPS points each)\n"
                "2. Use Haversine formula for distances — NOT Euclidean. Euclidean distance on "
                "lat/lon gives wrong results for geographic data.\n"
                "3. Compute total path length per route by summing Haversine distances between "
                "consecutive GPS points\n"
                "4. Group routes by origin-destination (OD) pair (snap start/end to ~0.01° grid)\n"
                "5. For each OD pair: compute mean and std of path lengths\n"
                "6. Flag routes where z-score = (path_length - mean) / std > 2.0\n"
                "7. There are 5 OD pairs, each with 35 normal + 5 anomalous routes\n"
                "8. Anomalous routes are 2.7-3.3x longer than normal for the same OD pair\n\n"
                "## Answer\n"
                '{"n_anomalous_routes": 25, '
                '"anomalous_route_ids": [35-39, 75-79, 115-119, 155-159, 195-199], '
                '"distance_method": "haversine", '
                '"detection_method": "z-score > 2.0 on path length per OD pair"}\n\n'
                "1. Sreason (Reasoning Process, weight 0.3): Did the agent recognize this requires "
                "grouping routes by OD pair before comparing? Did it justify using Haversine over "
                "Euclidean? Did it understand why geographic distance calculation matters here?\n\n"
                "2. Scode (Code Steps, weight 0.3): Is the Haversine formula correctly implemented? "
                "Does the code correctly group routes by origin-destination pairs? Does it compute "
                "z-scores or equivalent outlier detection? Are the visualizations informative?\n\n"
                "3. Sresult (Final Result, weight 0.4): Did the agent correctly identify all 25 "
                "anomalous routes? Are false positives minimal? "
                f"Agent detected: {len(predicted_set)} routes, {N_GT} correct, {n_fp} false positives. "
                "A naive agent using Euclidean distance would still likely find most anomalies since "
                "the detours are extreme — the key distinction is correctly declaring 'haversine'.\n\n"
                "The final weighted score: Sreason*0.3 + Scode*0.3 + Sresult*0.4 (max 1.0). "
                "A score >= 0.6 is passing.\n\n"
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
print(f"\nFinal reward: {reward}")

out = {
    "route_detection_check": route_detection_check,
    "haversine_check":       haversine_check,
    "Sreason":               Sreason,
    "Scode":                 Scode,
    "Sresult":               Sresult,
    "weighted_score":        weighted_score,
    "reward":                reward,
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
