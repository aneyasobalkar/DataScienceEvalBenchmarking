#!/bin/bash
set -Eeuo pipefail

echo "=== Bengali Fake News Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"macro_f1_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
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
    out = {"macro_f1_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(f"results.json parse error: {e}")
    sys.exit(1)

macro_f1     = float(results.get("macro_f1", 0))
per_source   = results.get("per_source_f1", {})
f1_check     = bool(macro_f1 > 0.75)
source_check = bool(isinstance(per_source, dict) and len(per_source) >= 3)

print(f"Macro F1:       {macro_f1:.4f}  ->  {'PASS' if f1_check else 'FAIL'} (need > 0.75)")
print(f"Per-source F1:  {len(per_source)} sources  ->  {'PASS' if source_check else 'FAIL'} (need ≥ 3)")

macro_f1_check = int(f1_check and source_check)

# ── Part 2: LLM-as-judge (only if deterministic checks pass) ─────────────────
Sreason = 0.0
Scode   = 0.0
Sresult = 0.0
weighted_score = 0.0
judge_reasoning = "Deterministic checks failed — LLM judge skipped"

if macro_f1_check:
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
                "You are evaluating a data science agent on a Bengali fake news detection task. "
                "Score the agent on three dimensions, each a float between 0.0 and 1.0:\n\n"
                "The reference solution approach is documented in the QRA pair for this task. "
                "Use the Reasoning section of the QRA as the benchmark for Sreason — if the "
                "agent followed a similar methodology it should score highly. Use the Answer "
                "section as the benchmark for Sresult — if the agent's output matches the "
                "expected structure and values it should score highly. Alternative valid "
                "approaches that reach the correct answer should still receive full credit.\n\n"
                "QRA Reference:\n\n"
                "## Question\n"
                "Given a multi-source Bengali fake news dataset with articles labeled as real "
                "or fake from multiple news outlets, build a lightweight text classification "
                "pipeline to distinguish real from fake news. Evaluate appropriately for this "
                "problem type.\n\n"
                "## Reasoning\n"
                "This is a multilingual NLP classification problem with several non-obvious "
                "challenges:\n"
                "1. Bengali text requires Unicode normalization — same characters can have "
                "multiple representations\n"
                "2. Standard English tokenizers will fail on Bengali script — need "
                "Bengali-aware tokenization\n"
                "3. Class imbalance is likely — real news typically outnumbers fake news\n"
                "4. Must use macro F1 as the evaluation metric, not accuracy — accuracy is "
                "misleading with imbalance\n"
                "5. TF-IDF vectorization with Bengali stopword removal is appropriate for "
                "a lightweight approach\n"
                "6. Logistic regression with class_weight='balanced' handles imbalance correctly\n"
                "7. Per-source evaluation is essential — a model that only works on one "
                "source is not generalizable\n\n"
                "## Answer\n"
                '{"macro_f1": ">0.75", "per_class_f1": {"real": ">0.75", "fake": ">0.70"}, '
                '"per_source_f1": {"<all sources present>": "<float>"}, '
                '"class_imbalance_handled": true, "bengali_preprocessing": true}\n\n'
                "1. Sreason (Reasoning Process, weight 0.3): Did the agent select appropriate "
                "techniques for Bengali text classification? Did it recognize key challenges like "
                "class imbalance (~2:1 real-to-fake) and multi-source evaluation? Is the "
                "methodological approach sound regardless of final accuracy?\n\n"
                "2. Scode (Code Steps, weight 0.3): Is the code logically coherent and free of "
                "fatal errors? Does it correctly produce intermediate outputs (vectorizer fit on "
                "train only, evaluation on test set, per-source breakdown)?\n\n"
                "3. Sresult (Final Result, weight 0.4): What is the holistic quality of the "
                "outcome — metrics, visualizations, and insights? Accept alternative valid "
                "approaches that differ from the reference solution.\n\n"
                "The final weighted score will be: Sreason*0.3 + Scode*0.3 + Sresult*0.4. "
                "A score of 0.6 or above is considered passing.\n\n"
                f"Agent trajectory:\n{trajectory_raw}\n\n"
                f"Agent results:\n{results_str}\n\n"
                "Respond with JSON only, no other text:\n"
                '{"Sreason": <0.0-1.0>, "Scode": <0.0-1.0>, "Sresult": <0.0-1.0>, "reasoning": "<two sentences>"}'
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
            weighted_score = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
            judge_reasoning = judge_result.get("reasoning", "")

            print(f"Sreason: {Sreason}  Scode: {Scode}  Sresult: {Sresult}")
            print(f"Weighted score: {weighted_score:.4f}  ->  {'PASS' if weighted_score >= 0.6 else 'FAIL'} (need ≥ 0.6)")
            print(f"Judge: {judge_reasoning}")

        except Exception as e:
            print(f"LLM judge failed ({e}) — falling back to deterministic-only")
            Sreason = 0.8; Scode = 0.8; Sresult = 0.8
            weighted_score = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
            judge_reasoning = f"API unavailable ({e}); deterministic checks passed"

# ── Final reward ──────────────────────────────────────────────────────────────
reward = 1 if (macro_f1_check and weighted_score >= 0.6) else 0
print(f"\nFinal reward: {reward}")

out = {
    "macro_f1_check":  macro_f1_check,
    "Sreason":         Sreason,
    "Scode":           Scode,
    "Sresult":         Sresult,
    "weighted_score":  weighted_score,
    "reward":          reward,
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
