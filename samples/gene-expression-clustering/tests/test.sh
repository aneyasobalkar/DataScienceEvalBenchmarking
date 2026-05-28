#!/bin/bash
set -Eeuo pipefail

echo "=== Gene Expression Clustering Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"silhouette_check":0,"pca_reduction_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
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
    out = {"silhouette_check":0,"pca_reduction_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(str(e))
    sys.exit(1)

sil       = float(results.get("silhouette_score", 0))
n_comp    = int(results.get("n_components_pca", 999))

sil_check = bool(sil > 0.3)
pca_check = bool(n_comp < 50)

print(f"Silhouette score:  {sil:.4f}  ->  {'PASS' if sil_check else 'FAIL'} (need > 0.3)")
print(f"PCA components:    {n_comp}     ->  {'PASS' if pca_check else 'FAIL'} (need < 50)")

det_pass = int(sil_check and pca_check)

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
                "You are evaluating a data science agent on a high-dimensional gene expression clustering task. "
                "The dataset has ~7000 gene features and only ~70 samples — naive clustering without "
                "dimensionality reduction will fail. Score the agent on three dimensions, each 0-1:\n\n"
                "The reference solution approach is documented in the QRA pair for this task. "
                "Use the Reasoning section of the QRA as the benchmark for Sreason — if the "
                "agent followed a similar methodology it should score highly. Use the Answer "
                "section as the benchmark for Sresult — if the agent's output matches the "
                "expected structure and values it should score highly. Alternative valid "
                "approaches that reach the correct answer should still receive full credit.\n\n"
                "QRA Reference:\n\n"
                "## Question\n"
                "Given a high-dimensional gene expression dataset of cancer patient samples "
                "with ~7000 gene features, cluster the samples into biologically meaningful "
                "groups. The data contains measurements from patients with different cancer "
                "subtypes.\n\n"
                "## Reasoning\n"
                "This is a high-dimensional clustering problem where n_samples << n_features:\n"
                "1. Standardize features first since gene expression values have different scales\n"
                "2. Apply PCA to reduce dimensions while retaining >=85% variance — this "
                "should yield ~10-20 components\n"
                "3. Use the elbow method and silhouette analysis to determine optimal k\n"
                "4. Cluster in reduced space using k-means or hierarchical clustering\n"
                "5. Evaluate with silhouette score and Davies-Bouldin index — NOT accuracy "
                "since this is unsupervised\n"
                "6. Visualize clusters in 2D PCA space to check biological plausibility\n"
                "7. Clustering directly in 7000 dimensions is meaningless — dimensionality "
                "reduction is mandatory\n\n"
                "## Answer\n"
                '{"silhouette_score": ">0.3", "n_components_pca": "<50", '
                '"variance_explained": ">=0.85", "n_clusters": "2-5", '
                '"visualizations": ["scree_plot.png", "pca_clusters.png", "silhouette.png"]}\n\n'
                "1. Sreason (Reasoning Process, weight 0.3): Did the agent recognise that dimensionality "
                "reduction is necessary before clustering high-dimensional data? Did it justify the choice "
                "of number of components and clusters using scree plots or silhouette analysis? Is the "
                "methodology sound regardless of exact approach?\n\n"
                "2. Scode (Code Steps, weight 0.3): Is the code logically coherent and free of fatal errors? "
                "Does it standardise before reducing dimensions? Does it correctly evaluate clustering quality "
                "with appropriate unsupervised metrics?\n\n"
                "3. Sresult (Final Result, weight 0.4): What is the holistic quality of the outcome — "
                "clustering metrics, visualizations (scree plot, PCA scatter, silhouette diagram), and "
                "biological interpretability? Accept valid alternative approaches.\n\n"
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
    "silhouette_check":    int(sil_check),
    "pca_reduction_check": int(pca_check),
    "Sreason":             Sreason,
    "Scode":               Scode,
    "Sresult":             Sresult,
    "weighted_score":      weighted_score,
    "reward":              reward,
}
with open("/logs/verifier/reward.json",       "w") as f: json.dump(out, f, indent=2)
with open("/logs/verifier/reward.txt",        "w") as f: f.write(str(reward))
with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(judge_reasoning)

sys.exit(0 if reward == 1 else 1)
PYEOF

exit_code=$?
if   [ $exit_code -eq 0 ]; then echo "All checks passed"
else                              echo "One or more checks failed"
fi
exit 0
