#!/bin/bash
set -Eeuo pipefail

echo "=== Logistics Carrier Optimizer Verifier ==="
mkdir -p /logs/verifier

CORRECT_ANSWER="PrimeLogistics:38505.40"

if [ ! -f /app/answer.txt ]; then
    echo "Error: /app/answer.txt not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"reward":0,"binary_reward":0,"fractional_reward":0.0,"agent_answer":"","correct_answer":"'"$CORRECT_ANSWER"'","reason":"answer.txt missing"}' > /logs/verifier/reward.json
    exit 0
fi

python3 - <<'PYEOF'
import json, sys

CORRECT_CARRIER = "primelogistics"
CORRECT_COST    = 38505.40
CORRECT_STR     = "PrimeLogistics:38505.40"

def parse(s):
    s = s.strip().strip('{}')
    if ':' in s:
        idx = s.rfind(':')
        carrier = s[:idx].strip()
        try:
            cost = float(s[idx+1:].strip())
        except ValueError:
            cost = None
        return carrier, cost
    return None, None

with open("/app/answer.txt") as f:
    agent_raw = f.read().strip().replace(' ', '')

ac, av = parse(agent_raw)

carrier_check = int(ac is not None and ac.lower() == CORRECT_CARRIER)
value_check   = int(av is not None and abs(av - CORRECT_COST) <= 0.01)

reward           = 1 if (carrier_check and value_check) else 0
binary_reward    = reward
fractional_reward = round(0.5 * carrier_check + 0.5 * value_check, 4)

print(f"Agent answer:   {agent_raw}")
print(f"Correct answer: {CORRECT_STR}")
print(f"Carrier check: {'PASS' if carrier_check else 'FAIL'} ({ac!r} vs {CORRECT_CARRIER!r})")
print(f"Value check:   {'PASS' if value_check else 'FAIL'} ({av} vs {CORRECT_COST})")
print(f"Binary reward:     {binary_reward}")
print(f"Fractional reward: {fractional_reward}")
print(f"Final reward: {reward}")

out = {
    "reward":            reward,
    "binary_reward":     binary_reward,
    "fractional_reward": fractional_reward,
    "carrier_check":     carrier_check,
    "value_check":       value_check,
    "agent_answer":      agent_raw,
    "correct_answer":    CORRECT_STR,
}
with open("/logs/verifier/reward.json", "w") as f: json.dump(out, f, indent=2)
with open("/logs/verifier/reward.txt",  "w") as f: f.write(str(reward))
sys.exit(0 if reward == 1 else 1)
PYEOF

exit_code=$?
if [ $exit_code -eq 0 ]; then echo "PASS"; else echo "FAIL"; fi
exit 0
