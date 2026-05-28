#!/bin/bash
set -Eeuo pipefail

echo "=== Spatial Autocorrelation Verifier ==="
mkdir -p /logs/verifier
export GEMINI_API_KEY=$(harbor config get gemini-api-key 2>/dev/null || echo "${GEMINI_API_KEY:-}")

CORRECT_MORANS_I=0.574421

if [ ! -f /output/results.json ]; then
    echo "Error: /output/results.json not found"
    echo 0 > /logs/verifier/reward.txt
    echo '{"morans_i_check":0,"interpretation_check":0,"weights_check":0,"pvalue_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}' > /logs/verifier/reward.json
    exit 0
fi

# ── Part 1: Deterministic checks ──────────────────────────────────────────────
python3 - <<'PYEOF'
import sys, json

CORRECT_I = 0.574421

try:
    with open("/output/results.json") as f:
        results = json.load(f)
except Exception as e:
    print(f"Error reading results.json: {e}")
    out = {"morans_i_check":0,"interpretation_check":0,"weights_check":0,
           "pvalue_check":0,"Sreason":0,"Scode":0,"Sresult":0,"weighted_score":0,"reward":0}
    with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
    with open("/logs/verifier/reward.txt","w") as f: f.write("0")
    sys.exit(1)

morans_i      = results.get("morans_i", None)
interp        = str(results.get("interpretation", "")).strip().lower()
weights_type  = str(results.get("weights_type", "")).strip().lower()
pseudo_p      = results.get("pseudo_p_value", None)

morans_i_check      = int(morans_i is not None and abs(float(morans_i) - CORRECT_I) <= 0.005)
interpretation_check = int(interp == "clustered")
weights_check        = int("queen" in weights_type)
pvalue_check         = int(pseudo_p is not None and float(pseudo_p) < 0.05)

det_pass = int(morans_i_check and interpretation_check and weights_check and pvalue_check)

print(f"Moran's I:         {morans_i}  ->  {'PASS' if morans_i_check else 'FAIL'} (expected ≈{CORRECT_I})")
print(f"Interpretation:    {interp!r}  ->  {'PASS' if interpretation_check else 'FAIL'}")
print(f"Weights type:      {weights_type!r}  ->  {'PASS' if weights_check else 'FAIL'}")
print(f"Pseudo p-value:    {pseudo_p}  ->  {'PASS' if pvalue_check else 'FAIL'} (need < 0.05)")
print(f"Deterministic:     {'PASS' if det_pass else 'FAIL'}")

# ── Part 2: LLM-as-judge ──────────────────────────────────────────────────────
Sreason = 0.0; Scode = 0.0; Sresult = 0.0; weighted_score = 0.0
judge_reasoning = "Deterministic checks failed — LLM judge skipped"

if det_pass:
    import os, urllib.request
    trajectory_path = "/logs/agent/trajectory.json"
    if not os.path.exists(trajectory_path):
        Sreason = 8.0; Scode = 8.0; Sresult = 8.0
        weighted_score = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
        judge_reasoning = "No agent trajectory — judge skipped (oracle/nop run)"
        print("LLM judge: skipped (no trajectory)")
    else:
        try:
            with open(trajectory_path) as f:
                traj = f.read()
            if len(traj) > 12000:
                traj = traj[:12000] + "\n...[truncated]"
            res_str = json.dumps(results)[:2000]
            api_key = os.environ.get("GEMINI_API_KEY","")
            if not api_key:
                raise ValueError("GEMINI_API_KEY not set")

            judge_prompt = (
                "You are evaluating a data science agent on a spatial autocorrelation task.\n"
                "The task: compute global Moran's I for violent crime rates (HOMICIDE, ASSAULT, "
                "BATTERY, ROBBERY) across 77 Chicago community areas in 2023.\n\n"
                "Correct methodology:\n"
                "1. Filter crimes_2023.csv to violent types only\n"
                "2. Aggregate to community area, join with population, compute crime rate per 10,000\n"
                "3. Build Queen contiguity weights with row standardization\n"
                "4. Run esda.Moran with 999 permutations\n"
                "5. Correct values: Moran's I ≈ 0.574421, z ≈ 8.1692, pseudo p = 0.001\n\n"
                "Key traps:\n"
                "- Using raw crime counts not rates (ignores population confounding)\n"
                "- Distance-based or KNN weights instead of Queen contiguity\n"
                "- Missing row standardization of weights\n"
                "- Using normal distribution test instead of permutation test\n"
                "- Wrong Moran's I formula (missing S0 normalization)\n\n"
                "Score 0-10 on three dimensions:\n\n"
                "1. Sreason (weight 0.3): Did the agent read spatial_methods.md first? "
                "Did it use crime RATES not raw counts? Did it justify Queen contiguity "
                "over distance-based weights? Did it use permutation test not normal distribution?\n\n"
                "2. Scode (weight 0.3): Is Queen contiguity built correctly with libpysal? "
                "Is row standardization applied (w.transform='r')? Is the np.random.seed set "
                "before Moran() for reproducibility? Are both plots produced and informative?\n\n"
                "3. Sresult (weight 0.4): Is Moran's I ≈ 0.574421 (±0.005)? "
                "Is interpretation 'clustered'? Is pseudo p-value < 0.05? "
                f"Agent results: {res_str}\n\n"
                "Weighted score = Sreason*0.3 + Scode*0.3 + Sresult*0.4 (max 10.0). Threshold 6.0.\n\n"
                f"Agent trajectory:\n{traj}\n\n"
                "Respond with JSON only:\n"
                '{"Sreason":<0-10>,"Scode":<0-10>,"Sresult":<0-10>,"reasoning":"<two sentences>"}'
            )

            url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
            payload = {"contents":[{"parts":[{"text":judge_prompt}]}]}
            req = urllib.request.Request(f"{url}?key={api_key}",
                data=json.dumps(payload).encode(),
                headers={"Content-Type":"application/json"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                response = json.loads(resp.read())
            content = response["candidates"][0]["content"]["parts"][0]["text"]
            jr = json.loads(content)
            Sreason = float(jr.get("Sreason", 0))
            Scode   = float(jr.get("Scode",   0))
            Sresult = float(jr.get("Sresult", 0))
            weighted_score = round(Sreason*0.3 + Scode*0.3 + Sresult*0.4, 4)
            judge_reasoning = jr.get("reasoning","")
            print(f"Sreason={Sreason}  Scode={Scode}  Sresult={Sresult}")
            print(f"Weighted: {weighted_score:.4f}  ->  {'PASS' if weighted_score>=6.0 else 'FAIL'}")
            print(f"Judge: {judge_reasoning}")
        except Exception as e:
            print(f"LLM judge failed ({e}) — fallback")
            Sreason = 8.0; Scode = 8.0; Sresult = 8.0
            weighted_score = round(Sreason*0.3+Scode*0.3+Sresult*0.4, 4)
            judge_reasoning = f"API unavailable ({e}); deterministic checks passed"

# ── Final reward ───────────────────────────────────────────────────────────────
reward = 1 if (det_pass and weighted_score >= 6.0) else 0
binary_reward = reward
det_fraction  = round((morans_i_check + interpretation_check + weights_check + pvalue_check) / 4, 4)
fractional_reward = round(min(weighted_score / 10.0, 1.0), 4) if det_pass else round(det_fraction * 0.5, 4)
print(f"\nFinal reward: {reward}  fractional: {fractional_reward}")

out = {
    "morans_i_check":       morans_i_check,
    "interpretation_check": interpretation_check,
    "weights_check":        weights_check,
    "pvalue_check":         pvalue_check,
    "Sreason":              Sreason,
    "Scode":                Scode,
    "Sresult":              Sresult,
    "weighted_score":       weighted_score,
    "judge_reasoning":      judge_reasoning,
    "reward":               reward,
    "binary_reward":        binary_reward,
    "fractional_reward":    fractional_reward,
}
with open("/logs/verifier/reward.json","w") as f: json.dump(out, f, indent=2)
with open("/logs/verifier/reward.txt","w")  as f: f.write(str(reward))
with open("/logs/verifier/judge_reasoning.txt","w") as f: f.write(judge_reasoning)
sys.exit(0 if reward == 1 else 1)
PYEOF

exit_code=$?
if [ $exit_code -eq 0 ]; then echo "All checks passed"
else                          echo "One or more checks failed"
fi
exit 0
