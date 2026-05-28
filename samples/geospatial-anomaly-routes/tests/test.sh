#!/bin/bash
set -Eeuo pipefail

echo "=== Geospatial Route Anomaly Detection Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"precision":0,"recall":0,"f1_score":0,"true_positives":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
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
    out = {"precision":0,"recall":0,"f1_score":0,"true_positives":0,
           "Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(str(e))
    sys.exit(1)

predicted = results.get("anomalous_route_ids", [])
if not isinstance(predicted, list):
    predicted = []
predicted_set = set(int(x) for x in predicted)
gt_set = set(GROUND_TRUTH)

tp = len(predicted_set & gt_set)
fp = len(predicted_set - gt_set)
fn = len(gt_set - predicted_set)

precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
recall    = tp / (tp + fn) if (tp + fn) > 0 else 0.0
f1        = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0

print(f"Predicted: {sorted(predicted_set)}")
print(f"Ground truth: {sorted(gt_set)}")
print(f"TP={tp}, FP={fp}, FN={fn}")
print(f"Precision={precision:.3f}, Recall={recall:.3f}, F1={f1:.3f}")

det_pass = int(f1 >= 0.6)
print(f"Deterministic check: {'PASS' if det_pass else 'FAIL'} (need F1 >= 0.6)")

Sreason = 0.0; Scode = 0.0; Sresult = 0.0
weighted_score = 0.0
judge_reasoning = "Deterministic check failed — LLM judge skipped"

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

            judge_prompt = (
                "You are evaluating a data science agent on a geospatial route anomaly detection task. "
                "The dataset contains 605 GPS routes in Beijing, with 5 synthetic anomalous routes "
                "injected. The anomalous routes take dramatically longer detours between the same "
                "origin-destination pair as normal routes.\n\n"
                "The reference solution approach is documented below. "
                "Score the agent on three dimensions, each 0-1:\n\n"
                "QRA Reference:\n\n"
                "## Question\n"
                "Detect anomalous GPS routes in Beijing trajectory data. Routes are anomalous if their "
                "Haversine path length is more than 3 standard deviations above the mean for the same "
                "origin-destination (OD) pair.\n\n"
                "## Reasoning\n"
                "1. Load trajectories.csv (25,005 rows, 605 routes)\n"
                "2. For each route, sum Haversine distances between consecutive GPS points → path_length_m\n"
                "3. Snap start/end coords to 0.01-degree grid cells (round to 2dp) → OD pair key\n"
                "4. For each OD pair with >= 3 routes: compute mean and std of path lengths\n"
                "5. Flag routes where z-score = (path_length - mean) / std > 3.0 as anomalous\n"
                "6. The 5 anomalous routes (IDs 600-604) have z-scores of 3.6-4.1 vs normal routes max z=3.0\n"
                "7. Critical: must use Haversine (spherical earth) not Euclidean distance for accuracy\n"
                "8. Normal routes take 1.1-1.2x the straight-line distance; anomalies take 1.5-3x normal mean\n\n"
                "## Answer\n"
                '{"anomalous_route_ids": [600, 601, 602, 603, 604], '
                '"method": "haversine path length + z-score per OD pair (threshold z > 3.0)", '
                '"od_pairs_analyzed": 30}\n\n'
                "1. Sreason (Reasoning Process, weight 0.3): Did the agent understand OD-pair grouping? "
                "Did it justify the z-score threshold? Did it recognize Haversine is needed?\n\n"
                "2. Scode (Code Steps, weight 0.3): Did the agent correctly implement Haversine? "
                "Did it properly group by OD pair (0.01-degree grid)? Did it compute z-scores correctly? "
                "Are visualizations informative?\n\n"
                "3. Sresult (Final Result, weight 0.4): Did the agent correctly identify the anomalous "
                "routes? Penalize heavily for large numbers of false positives. "
                f"Agent found: {sorted(predicted_set)} vs ground truth: {sorted(gt_set)}. "
                f"F1={f1:.3f}, Precision={precision:.3f}, Recall={recall:.3f}.\n\n"
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

reward = 1 if (det_pass and weighted_score >= 0.6) else 0
print(f"\nFinal reward: {reward}")

out = {
    "precision":      round(precision, 4),
    "recall":         round(recall, 4),
    "f1_score":       round(f1, 4),
    "true_positives": tp,
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
