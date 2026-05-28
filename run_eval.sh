#!/bin/bash
set -euo pipefail

cd /Users/aneyasobalkar/PythonScripts2/takehomeassessment
source .venv/bin/activate
set -a && source .env && set +a

TASKS=(
  dabstep-1305
  dabstep-1394
  dabstep-2366
  dabstep-2463
  dabstep-2477
  dabstep-2534
  dabstep-2543
  dabstep-2641
  dabstep-2710
  dabstep-2764
  radial-velocity-period
  lottery-ticket-mnist
)

SUMMARY_FILE="eval_summary.txt"
echo "=== Eval run started: $(date) ===" > "$SUMMARY_FILE"

for task in "${TASKS[@]}"; do
  for trial in 1 2 3; do
    echo "--- $task trial $trial / 3 ---" | tee -a "$SUMMARY_FILE"
    reward=$(harbor run -p "samples/$task" -a terminus-2 -m gemini/gemini-3.5-flash -y 2>&1 \
      | tee -a "$SUMMARY_FILE" \
      | grep "Mean:" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    echo "RESULT $task trial=$trial reward=$reward" | tee -a "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
  done
done

echo "=== Eval run finished: $(date) ===" | tee -a "$SUMMARY_FILE"
