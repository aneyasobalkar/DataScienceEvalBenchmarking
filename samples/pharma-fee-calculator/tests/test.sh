#!/bin/bash
set -Eeuo pipefail

echo "=== Pharma Fee Calculator Verifier ==="
mkdir -p /logs/verifier

CORRECT_ANSWER="[Neurology: 4223.36, Immunology: 5934.23, Oncology: 7485.73, Rare_Disease: 8169.56, Cardiology: 10556.83]"

if [ ! -f /app/answer.txt ]; then
    echo "Error: /app/answer.txt not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"reward":0,"agent_answer":"","correct_answer":"'"$CORRECT_ANSWER"'","reason":"answer.txt missing"}' > /logs/verifier/reward.json
    exit 0
fi

AGENT_ANSWER=$(cat /app/answer.txt)

REWARD=$(python3 -c "
import re, sys

def normalize(s):
    s = s.strip()
    s = re.sub(r'\s*:\s*', ':', s)
    s = re.sub(r'\s*,\s*', ',', s)
    return s.lower()

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

agent_raw   = '''$AGENT_ANSWER'''
correct_raw = '''$CORRECT_ANSWER'''

# Try exact match after normalization
if normalize(agent_raw) == normalize(correct_raw):
    print(1)
    sys.exit()

# Try numeric tolerance ±0.01
agent_pairs   = parse_pairs(agent_raw)
correct_pairs = parse_pairs(correct_raw)

if set(agent_pairs.keys()) != set(correct_pairs.keys()):
    print(0)
    sys.exit()

for k in correct_pairs:
    if abs(agent_pairs.get(k, 1e9) - correct_pairs[k]) > 0.01:
        print(0)
        sys.exit()

print(1)
")

echo "Agent answer:   $AGENT_ANSWER"
echo "Correct answer: $CORRECT_ANSWER"
echo "Reward:         $REWARD"

echo $REWARD > /logs/verifier/reward.txt
echo "{\"reward\":$REWARD,\"agent_answer\":\"$AGENT_ANSWER\",\"correct_answer\":\"$CORRECT_ANSWER\"}" > /logs/verifier/reward.json

if [ "$REWARD" = "1" ]; then
    echo "PASS"
else
    echo "FAIL"
fi
exit 0
