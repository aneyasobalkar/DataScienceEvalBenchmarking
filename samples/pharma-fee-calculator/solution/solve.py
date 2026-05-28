import pandas as pd

# Fee rules from billing_manual.md
MULTIPLIERS = {
    "Oncology":    1.3,
    "Cardiology":  1.1,
    "Neurology":   1.0,
    "Immunology":  1.2,
    "Rare_Disease":1.5,
}
EU_COUNTRIES = {"DE", "FR", "NL", "ES", "IT"}
ACI_SURCHARGE = {"A", "B", "C"}
SURCHARGE_OLD = 0.025
SURCHARGE_NEW = 0.040

df = pd.read_csv("/data/trials.csv", parse_dates=["date"])

filt = df[
    (df["company"] == "BioPharm_Corp") &
    (df["date"].dt.year == 2023) &
    (df["date"].dt.month.isin([7, 8, 9]))
].copy()

filt["multiplier"]     = filt["drug_class"].map(MULTIPLIERS)
filt["adjusted_fee"]   = filt["base_fee_eur"] * filt["patient_count"] * filt["multiplier"]
filt["surcharge_flag"] = (
    (filt["trial_phase"] == "Phase_III") &
    (filt["country_code"].isin(EU_COUNTRIES)) &
    (filt["aci"].isin(ACI_SURCHARGE))
)

filt["fee_old"] = filt["adjusted_fee"] * (1 + SURCHARGE_OLD * filt["surcharge_flag"])
filt["fee_new"] = filt["adjusted_fee"] * (1 + SURCHARGE_NEW * filt["surcharge_flag"])
filt["delta"]   = filt["fee_new"] - filt["fee_old"]

by_class = filt.groupby("drug_class")["delta"].sum().reset_index()
by_class = by_class.sort_values("delta").reset_index(drop=True)

parts = [f"{row['drug_class']}: {row['delta']:.2f}" for _, row in by_class.iterrows()]
answer = "[" + ", ".join(parts) + "]"

with open("/app/answer.txt", "w") as f:
    f.write(answer + "\n")

print(answer)
