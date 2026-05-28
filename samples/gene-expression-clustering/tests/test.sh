#!/bin/bash
set -Eeuo pipefail

echo "=== Gene Expression Clustering Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"silhouette_check":0,"pca_reduction_check":0,"batch_independence_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
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
    out = {"silhouette_check":0,"pca_reduction_check":0,"batch_independence_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(str(e))
    sys.exit(1)

sil       = float(results.get("silhouette_score", 0))
n_comp    = int(results.get("n_components_pca", 999))

# Batch-independence check: clusters must NOT align with the 3 batch/lab labels
# ARI(cluster_labels, batch_labels) < 0.3 means clustering is biology-driven, not batch-driven
batch_ari = 1.0  # default to fail
try:
    import csv as _csv
    batch_map = {}
    with open("/data/sample_metadata.csv") as bf:
        reader = _csv.DictReader(bf)
        for row in reader:
            batch_map[row["sample_id"]] = row["batch"]
    # batch labels in sample order (sample_1..sample_72)
    ordered_samples = sorted(batch_map.keys(), key=lambda s: int(s.split("_")[1]))
    batch_str = [batch_map[s] for s in ordered_samples]
    unique_batches = sorted(set(batch_str))
    batch_int = [unique_batches.index(b) for b in batch_str]

    cluster_labels_raw = results.get("cluster_labels", [])
    if len(cluster_labels_raw) == len(batch_int):
        from sklearn.metrics import adjusted_rand_score as _ari
        batch_ari = _ari(batch_int, cluster_labels_raw)
    else:
        print(f"cluster_labels length mismatch: got {len(cluster_labels_raw)}, expected {len(batch_int)}")
except Exception as e_batch:
    print(f"Batch ARI computation failed: {e_batch}")

sil_check   = bool(sil > 0.3)
pca_check   = bool(n_comp < 50)
batch_check = bool(batch_ari < 0.3)

print(f"Silhouette score:       {sil:.4f}   ->  {'PASS' if sil_check   else 'FAIL'} (need > 0.3)")
print(f"PCA components:         {n_comp}      ->  {'PASS' if pca_check   else 'FAIL'} (need < 50)")
print(f"Batch independence ARI: {batch_ari:.4f}  ->  {'PASS' if batch_check else 'FAIL'} (need ARI < 0.3 vs batch labels)")

det_pass = int(sil_check and pca_check and batch_check)

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
                "You are evaluating a data science agent on a gene expression clustering task with batch effects. "
                "The dataset has samples from 3 labs (batches). Without batch correction, clustering returns "
                "3 clusters aligned to the 3 labs — NOT the true cancer subtypes. The agent must detect and "
                "correct the batch effects before clustering. Score on three dimensions, each 0-1:\n\n"
                "QRA Reference:\n\n"
                "## Question\n"
                "Given a high-dimensional gene expression dataset with samples from 3 different labs, "
                "cluster the samples into biologically meaningful cancer subtypes. Samples come from "
                "lab_A, lab_B, and lab_C. Batch effects from the labs dominate the naive analysis.\n\n"
                "## Reasoning\n"
                "This is a batch-confounded clustering problem:\n"
                "1. Load sample_metadata.csv to get batch (lab) labels per sample\n"
                "2. Naive PCA/clustering without correction → 3 clusters = 3 labs (ARI~1.0 with batch)\n"
                "3. Must detect and correct batch effects before clustering\n"
                "4. Batch correction methods: mean-centering per batch, ComBat, or removeBatchEffect\n"
                "5. After correction → 3 true cancer subtype clusters emerge (sil > 0.3)\n"
                "6. Verify: corrected clusters must NOT align with batch labels (ARI < 0.3)\n"
                "7. A naive agent reports batch-aligned clusters with high sil=0.55 but wrong biology\n\n"
                "## Answer\n"
                '{"silhouette_score": ">0.3", "n_components_pca": "<50", '
                '"n_clusters": 3, "cluster_labels": [0..2 for each sample], '
                '"batch_correction_applied": true, "ARI_vs_batch": "<0.3"}\n\n'
                "1. Sreason (Reasoning Process, weight 0.3): Did the agent check whether clusters "
                "correlate with batch labels? Did it apply a batch correction method before clustering? "
                "Did it recognize the batch effect as the dominant confound?\n\n"
                "2. Scode (Code Steps, weight 0.3): Does the code load sample_metadata.csv and use batch "
                "labels? Does it correctly implement batch correction? Does it verify batch-independence "
                "of the final clustering? Does it produce visualizations showing before/after correction?\n\n"
                "3. Sresult (Final Result, weight 0.4): Do the final cluster labels avoid batch alignment "
                "(ARI vs batch < 0.3)? Is silhouette > 0.3 after correction? Does it identify 3 clusters? "
                "Agents that skip batch correction and cluster by lab score 0 on this dimension.\n\n"
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
    "silhouette_check":        int(sil_check),
    "pca_reduction_check":     int(pca_check),
    "batch_independence_check": int(batch_check),
    "batch_ari":               round(float(batch_ari), 4),
    "Sreason":                 Sreason,
    "Scode":                   Scode,
    "Sresult":                 Sresult,
    "weighted_score":          weighted_score,
    "reward":                  reward,
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
