#!/bin/bash
set -Eeuo pipefail

echo "=== Logistics Carrier Optimizer Verifier ==="
mkdir -p /logs/verifier

CORRECT_ANSWER="PrimeLogistics:38505.40"

if [ ! -f /app/answer.txt ]; then
    echo "Error: /app/answer.txt not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"reward":0,"agent_answer":"","correct_answer":"'"$CORRECT_ANSWER"'","reason":"answer.txt missing"}' > /logs/verifier/reward.json
    exit 0
fi

AGENT_ANSWER=$(cat /app/answer.txt | tr -d '[:space:]')

REWARD=$(python3 -c "
import sys, re

agent_raw   = '$AGENT_ANSWER'.strip()
correct_raw = '$CORRECT_ANSWER'.strip()

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

ac, av = parse(agent_raw)
cc, cv = parse(correct_raw)

if ac is None or cc is None:
    print(0)
    sys.exit()

if ac.lower() != cc.lower():
    print(0)
    sys.exit()

if av is None or cv is None:
    print(0)
    sys.exit()

if abs(av - cv) <= 0.01:
    print(1)
else:
    print(0)
")

echo "Agent answer:   $AGENT_ANSWER"
echo "Correct answer: $CORRECT_ANSWER"
echo "Reward:         $REWARD"

echo $REWARD > /logs/verifier/reward.txt
echo "{\"reward\":$REWARD,\"agent_answer\":\"$AGENT_ANSWER\",\"correct_answer\":\"$CORRECT_ANSWER\"}" > /logs/verifier/reward.json

if [ "$REWARD" = "1" ]; then echo "PASS"; else echo "FAIL"; fi
exit 0
