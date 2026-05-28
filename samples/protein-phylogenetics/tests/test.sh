#!/bin/bash
set -Eeuo pipefail

echo "=== Protein Phylogenetics Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")

CORRECT_ANSWER="O76357:P22910:6.5848"

if [ ! -f /app/answer.txt ]; then
    echo "Error: /app/answer.txt not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"deterministic_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
    exit 0
fi

AGENT_ANSWER=$(cat /app/answer.txt | tr -d '[:space:]')

# ── Part 1: Deterministic check ───────────────────────────────────────────────
DET_REWARD=$(python3 - <<PYEOF
import sys, re

agent_raw   = '$AGENT_ANSWER'.strip()
correct_raw = '$CORRECT_ANSWER'.strip()

def parse(s):
    parts = s.split(':')
    if len(parts) != 3:
        return None, None, None
    id1, id2 = sorted([parts[0].strip(), parts[1].strip()])
    try:
        dist = float(parts[2].strip())
    except ValueError:
        dist = None
    return id1, id2, dist

aid1, aid2, adist = parse(agent_raw)
cid1, cid2, cdist = parse(correct_raw)

if aid1 is None or cid1 is None:
    print(0); sys.exit()
if aid1 != cid1 or aid2 != cid2:
    print(f"# IDs wrong: got {aid1},{aid2} expected {cid1},{cid2}", file=sys.stderr)
    print(0); sys.exit()
if adist is None or cdist is None:
    print(0); sys.exit()
if abs(adist - cdist) <= 0.001:
    print(1)
else:
    print(f"# Distance wrong: got {adist:.4f} expected {cdist:.4f}", file=sys.stderr)
    print(0)
PYEOF
)

echo "Agent answer:   $AGENT_ANSWER"
echo "Correct answer: $CORRECT_ANSWER"
echo "Deterministic:  $DET_REWARD"

# ── Part 2: LLM-as-judge ──────────────────────────────────────────────────────
Sreason=0; Scode=0; Sresult=0; weighted_score=0
judge_reasoning="Deterministic check failed — LLM judge skipped"

if [ "$DET_REWARD" = "1" ]; then
    trajectory_path="/logs/agent/trajectory.json"
    if [ ! -f "$trajectory_path" ]; then
        Sreason=8; Scode=8; Sresult=8
        weighted_score=$(python3 -c "print(round($Sreason*0.3 + $Scode*0.3 + $Sresult*0.4, 4))")
        judge_reasoning="No agent trajectory — judge skipped (oracle/nop run)"
        echo "LLM judge: skipped (no trajectory)"
    else
        trajectory_raw=$(head -c 12000 "$trajectory_path")
        results_str="$AGENT_ANSWER"

        judge_prompt="You are evaluating a data science agent on a protein phylogenetics task.
The dataset contains 20 lysozyme C protein sequences (UniProt Swiss-Prot reviewed entries).
The correct method: pairwise global alignment using BLOSUM62 (gap open=-10, extend=-0.5),
then distance = -ln(score_ij / min(self_score_i, self_score_j)).
The correct most-distant pair is O76357 and P22910 with distance 6.5848.

Three critical traps:
1. Using edit/Hamming distance instead of BLOSUM62 -> wrong pair entirely
2. Skipping alignment, comparing raw positions -> wrong pair and wrong distance
3. Wrong normalization (e.g. normalizing by max instead of min self-score) -> wrong distance

Score the agent 0-10 on three dimensions:

1. Sreason (weight 0.3): Did the agent read substitution_manual.md before analysis?
Did it recognise that BLOSUM62 is required and explain why edit distance fails?
Did it justify the need for pairwise alignment before computing distances?

2. Scode (weight 0.3): Is BLOSUM62 correctly applied (e.g. BioPython PairwiseAligner
with substitution_matrices.load('BLOSUM62'), correct gap penalties)?
Is the distance formula correctly implemented as -ln(score/min_self_score)?
Is the computation applied to all 190 pairwise combinations?

3. Sresult (weight 0.4): Did the agent correctly identify O76357 and P22910 as the most
distant pair with distance ~6.5848?
Agent answer: $results_str vs correct: O76357:P22910:6.5848

Weighted score = Sreason*0.3 + Scode*0.3 + Sresult*0.4 (max 10.0). Passing threshold: 6.0.

Agent trajectory (truncated):
$trajectory_raw

Respond with JSON only:
{\"Sreason\": <0-10>, \"Scode\": <0-10>, \"Sresult\": <0-10>, \"reasoning\": \"<two sentences>\"}"

        api_key="${GEMINI_API_KEY:-}"
        if [ -z "$api_key" ]; then
            echo "GEMINI_API_KEY not set — skipping LLM judge"
            Sreason=8; Scode=8; Sresult=8
            weighted_score=$(python3 -c "print(round($Sreason*0.3+$Scode*0.3+$Sresult*0.4,4))")
            judge_reasoning="API key not set; deterministic check passed"
        else
            judge_response=$(python3 - <<JUDGEEOF
import json, urllib.request, os, sys

api_key = "$api_key"
prompt  = """$judge_prompt"""
url  = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
payload = {"contents": [{"parts": [{"text": prompt}]}]}
req = urllib.request.Request(f"{url}?key={api_key}",
    data=json.dumps(payload).encode(), headers={"Content-Type":"application/json"})
try:
    with urllib.request.urlopen(req, timeout=30) as r:
        resp = json.loads(r.read())
    content = resp["candidates"][0]["content"]["parts"][0]["text"]
    result  = json.loads(content)
    print(json.dumps(result))
except Exception as e:
    print(json.dumps({"Sreason":8,"Scode":8,"Sresult":8,"reasoning":f"API error: {e}"}))
JUDGEEOF
)
            Sreason=$(echo    "$judge_response" | python3 -c "import sys,json;print(json.load(sys.stdin).get('Sreason',0))" 2>/dev/null || echo 0)
            Scode=$(echo      "$judge_response" | python3 -c "import sys,json;print(json.load(sys.stdin).get('Scode',0))"   2>/dev/null || echo 0)
            Sresult=$(echo    "$judge_response" | python3 -c "import sys,json;print(json.load(sys.stdin).get('Sresult',0))" 2>/dev/null || echo 0)
            judge_reasoning=$(echo "$judge_response" | python3 -c "import sys,json;print(json.load(sys.stdin).get('reasoning',''))" 2>/dev/null || echo "parse error")
            weighted_score=$(python3 -c "print(round(float('$Sreason')*0.3+float('$Scode')*0.3+float('$Sresult')*0.4,4))")
        fi
    fi
fi

# ── Final reward ──────────────────────────────────────────────────────────────
reward=0
if [ "$DET_REWARD" = "1" ]; then
    reward=$(python3 -c "print(1 if float('${weighted_score:-0}') >= 6.0 else 0)")
fi

echo "Sreason=$Sreason  Scode=$Scode  Sresult=$Sresult  weighted=$weighted_score"
echo "Reward: $reward"
echo "$reward" > /logs/verifier/reward.txt
cat > /logs/verifier/reward.json <<JSON
{
  "deterministic_check": $DET_REWARD,
  "Sreason": $Sreason,
  "Scode": $Scode,
  "Sresult": $Sresult,
  "weighted_score": $weighted_score,
  "judge_reasoning": "$judge_reasoning",
  "reward": $reward
}
JSON
echo "$judge_reasoning" > /logs/verifier/judge_reasoning.txt
exit 0
