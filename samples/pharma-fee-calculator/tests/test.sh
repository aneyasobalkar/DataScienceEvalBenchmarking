#!/bin/bash
set -Eeuo pipefail

echo "=== Pharma Fee Calculator Verifier ==="
mkdir -p /logs/verifier

CORRECT_ANSWER="[Neurology: 4223.36, Immunology: 5934.23, Oncology: 7485.73, Rare_Disease: 8169.56, Cardiology: 10556.83]"

if [ ! -f /app/answer.txt ]; then
    echo "Error: /app/answer.txt not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"reward":0,"binary_reward":0,"fractional_reward":0.0,"agent_answer":"","correct_answer":"'"$CORRECT_ANSWER"'","reason":"answer.txt missing"}' > /logs/verifier/reward.json
    exit 0
fi

python3 - <<'PYEOF'
import re, json, sys

CORRECT_PAIRS = {
    "neurology":   4223.36,
    "immunology":  5934.23,
    "oncology":    7485.73,
    "rare_disease": 8169.56,
    "cardiology":  10556.83,
}
CORRECT_STR = "[Neurology: 4223.36, Immunology: 5934.23, Oncology: 7485.73, Rare_Disease: 8169.56, Cardiology: 10556.83]"

def parse_pairs(s):
    s = s.strip().strip('[]')
    pairs = {}
    for item in re.split(r',(?![^\[]*\])', s):
        item = item.strip()
        if ':' in item:
            k, v = item.split(':', 1)
            try:
                pairs[k.strip().lower()] = float(v.strip())
            except ValueError:
                pass
    return pairs

with open("/app/answer.txt") as f:
    agent_raw = f.read().strip()

agent_pairs = parse_pairs(agent_raw)

sub_checks = {}
for k, v in CORRECT_PAIRS.items():
    sub_checks[k] = int(abs(agent_pairs.get(k, float('inf')) - v) <= 0.01)

n_correct = sum(sub_checks.values())
reward           = 1 if n_correct == len(CORRECT_PAIRS) else 0
binary_reward    = reward
fractional_reward = round(n_correct / len(CORRECT_PAIRS), 4)

print(f"Agent answer:   {agent_raw}")
print(f"Correct answer: {CORRECT_STR}")
for k, v in sub_checks.items():
    print(f"  {k}: {'PASS' if v else 'FAIL'}")
print(f"Correct: {n_correct}/{len(CORRECT_PAIRS)}")
print(f"Binary reward:     {binary_reward}")
print(f"Fractional reward: {fractional_reward}")
print(f"Final reward: {reward}")

out = {
    "reward":            reward,
    "binary_reward":     binary_reward,
    "fractional_reward": fractional_reward,
    "agent_answer":      agent_raw,
    "correct_answer":    CORRECT_STR,
    **{f"{k}_check": v for k, v in sub_checks.items()},
}
with open("/logs/verifier/reward.json", "w") as f: json.dump(out, f, indent=2)
with open("/logs/verifier/reward.txt",  "w") as f: f.write(str(reward))
sys.exit(0 if reward == 1 else 1)
PYEOF

exit_code=$?
if [ $exit_code -eq 0 ]; then echo "PASS"; else echo "FAIL"; fi
exit 0
