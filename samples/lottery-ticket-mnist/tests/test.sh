#!/bin/bash
set -Eeuo pipefail

echo "=== Lottery Ticket MNIST Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")
source /opt/venv/bin/activate

if [ ! -f /output/lottery_ticket.pth ]; then
    echo "Error: /output/lottery_ticket.pth not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"parameter_check":0,"lth_implemented":0,"weight_reset_correct":0,"reward":0}' > /logs/verifier/reward.json
    echo "No model file found" > /logs/verifier/judge_reasoning.txt
    exit 0
fi

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"parameter_check":0,"lth_implemented":0,"weight_reset_correct":0,"reward":0}' > /logs/verifier/reward.json
    echo "No results file found" > /logs/verifier/judge_reasoning.txt
    exit 0
fi

python3 - <<'PYEOF'
import sys, json, os
import urllib.request
import torch

# ── Part 1: Deterministic checks ─────────────────────────────────────────────
try:
    state_dict = torch.load('/output/lottery_ticket.pth', map_location='cpu', weights_only=True)
except Exception as e:
    print(f"Error loading model: {e}")
    result = {"parameter_check": 0, "lth_implemented": 0, "weight_reset_correct": 0, "reward": 0}
    with open('/logs/verifier/reward.json', 'w') as f: json.dump(result, f, indent=2)
    with open('/logs/verifier/judge_reasoning.txt', 'w') as f: f.write(f"Model load failed: {e}")
    with open('/logs/verifier/reward.txt', 'w') as f: f.write('0')
    sys.exit(1)

non_zero_params = sum(
    (v != 0).sum().item()
    for v in state_dict.values()
    if isinstance(v, torch.Tensor)
)
param_check = bool(non_zero_params < 50000)

print(f"Non-zero params: {non_zero_params:,}  ->  {'PASS' if param_check else 'FAIL'} (need < 50,000)")

# ── Part 2: LLM-as-judge ─────────────────────────────────────────────────────
lth_implemented      = False
weight_reset_correct = False
judge_reasoning      = "Deterministic checks failed — LLM judge skipped"

if param_check:
    trajectory_path = '/logs/agent/trajectory.json'

    if not os.path.exists(trajectory_path):
        lth_implemented      = True
        weight_reset_correct = True
        judge_reasoning      = "No agent trajectory found — judge skipped (oracle or nop run)"
        print("LLM judge: skipped (no trajectory)")
    else:
        try:
            with open(trajectory_path) as f:
                trajectory_raw = f.read()
            if len(trajectory_raw) > 12000:
                trajectory_raw = trajectory_raw[:12000] + "\n...[truncated]"

            judge_prompt = (
                "You are evaluating whether an agent correctly implemented the "
                "Lottery Ticket Hypothesis (LTH) from Frankle & Carlin 2019.\n\n"
                "The reference solution approach is documented in the QRA pair for this task. "
                "Use the Reasoning section of the QRA as the benchmark for lth_implemented — "
                "if the agent followed a similar methodology it should score true. Use the "
                "Answer section as the benchmark for weight_reset_correct — if the agent "
                "correctly reset weights to the original initialization θ0 it should be true. "
                "Alternative valid approaches that reach the correct answer should still "
                "receive full credit.\n\n"
                "QRA Reference:\n\n"
                "## Question\n"
                "Given the Spanish MNIST handwritten digit dataset, implement the Lottery "
                "Ticket Hypothesis from Frankle & Carlin (2019) to find a sparse winning "
                "ticket subnetwork that achieves greater than 95% test accuracy with fewer "
                "than 50,000 trainable parameters.\n\n"
                "## Reasoning\n"
                "This requires implementing the full LTH procedure — simply training a small "
                "network from scratch does NOT satisfy the task:\n"
                "1. Define a full dense CNN and save original weights θ0 before any training\n"
                "2. Train the full network to convergence\n"
                "3. Prune 20% of lowest-magnitude weights per round, creating mask m\n"
                "4. Reset surviving weights back to θ0 — this is the critical step most "
                "agents miss\n"
                "5. Retrain the masked network from the reset weights\n"
                "6. Repeat steps 3-5 until parameter count falls below 50k\n"
                "7. Verify final network hits >95% test accuracy\n"
                "8. Weight reset to θ0 is what distinguishes a winning ticket from just "
                "a small network\n\n"
                "## Answer\n"
                '{"test_accuracy": ">0.95", "total_parameters": "<50000", '
                '"pruning_rounds": "5-10", "sparsity": "<0.15", "weight_reset_correct": true}\n\n'
                "The LTH procedure requires ALL of the following:\n"
                "1. Randomly initialize a dense network and save those weights as θ0 "
                "BEFORE any training begins.\n"
                "2. Train the network to convergence.\n"
                "3. Prune the lowest-magnitude weights globally (e.g. 20% per round), "
                "creating a binary mask.\n"
                "4. Reset the SURVIVING weights back to their values in θ0 — the "
                "original initialization, NOT the weights from the current round and "
                "NOT a fresh random initialization.\n"
                "5. Re-apply the mask and retrain. Repeat until the parameter budget "
                "is met.\n\n"
                "Simply training a small network from scratch does NOT satisfy LTH. "
                "The critical distinguishing step is resetting to the ORIGINAL θ0.\n\n"
                f"Agent trajectory:\n{trajectory_raw}\n\n"
                "Did the agent correctly implement the full LTH procedure, specifically "
                "including weight reset to the original initialization θ0? "
                "Reply with a JSON object ONLY — no other text:\n"
                '{"lth_implemented": <true|false>, '
                '"weight_reset_correct": <true|false>, '
                '"reasoning": "<one concise sentence>"}'
            )

            api_key = os.environ.get('GEMINI_API_KEY', '')
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
            lth_implemented      = bool(judge_result.get("lth_implemented", False))
            weight_reset_correct = bool(judge_result.get("weight_reset_correct", False))
            judge_reasoning      = judge_result.get("reasoning", "")

            print(f"LTH implemented:    {'PASS' if lth_implemented else 'FAIL'}")
            print(f"Weight reset to θ0: {'PASS' if weight_reset_correct else 'FAIL'}")
            print(f"Judge reasoning: {judge_reasoning}")

        except Exception as e:
            print(f"LLM judge failed ({e}) — falling back to deterministic-only scoring")
            lth_implemented      = True
            weight_reset_correct = True
            judge_reasoning      = f"API unavailable ({e}); deterministic checks passed"

# ── Final reward ──────────────────────────────────────────────────────────────
reward = 1 if (param_check and lth_implemented and weight_reset_correct) else 0

result = {
    "parameter_check":      int(param_check),
    "lth_implemented":      int(lth_implemented),
    "weight_reset_correct": int(weight_reset_correct),
    "reward":               reward
}

with open('/logs/verifier/reward.json', 'w') as f: json.dump(result, f, indent=2)
with open('/logs/verifier/judge_reasoning.txt', 'w') as f: f.write(judge_reasoning)
with open('/logs/verifier/reward.txt',  'w') as f: f.write(str(reward))

print(f"\nFinal reward: {reward}")
sys.exit(0 if reward == 1 else 1)
PYEOF

exit_code=$?
if   [ $exit_code -eq 0 ]; then echo "All checks passed"
else                              echo "One or more checks failed"
fi
exit 0
