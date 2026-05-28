import pandas as pd
import json

# Fee rules from carrier_contracts.md

def fastship_fee(weight, zone, cls):
    """zone*2.50/kg; >20kg: 15% discount on per-kg BEFORE multiplier; express: *1.8"""
    per_kg = zone * 2.50
    if weight > 20:
        per_kg *= 0.85
    fee = per_kg * weight
    if cls == "express":
        fee *= 1.8
    return fee

def reliable_fee(weight, zone, cls):
    """zone*3.00/kg; >15kg: 10% discount BEFORE multiplier; express: *1.5 + 2.50 flat"""
    per_kg = zone * 3.00
    if weight > 15:
        per_kg *= 0.90
    fee = per_kg * weight
    if cls == "express":
        fee = fee * 1.5 + 2.50
    return fee

def budget_fee(weight, zone, cls):
    """zone*2.00/kg; no weight break; express: *2.2; ALL shipments: +1.5% handling"""
    fee = zone * 2.00 * weight
    if cls == "express":
        fee *= 2.2
    return fee * 1.015

def prime_fee(weight, zone, cls):
    """zone*2.75/kg; >25kg: 20% discount BEFORE multiplier; express: *1.6 + 5.00 if zone>=4"""
    per_kg = zone * 2.75
    if weight > 25:
        per_kg *= 0.80
    fee = per_kg * weight
    if cls == "express":
        fee *= 1.6
        if zone >= 4:
            fee += 5.00
    return fee

FEE_FUNCS = {
    "FastShip":        fastship_fee,
    "ReliableExpress": reliable_fee,
    "BudgetFreight":   budget_fee,
    "PrimeLogistics":  prime_fee,
}

with open("/data/zones.json") as f:
    zones = json.load(f)

df = pd.read_csv("/data/shipments.csv", parse_dates=["date"])

filt = df[
    (df["company"] == "MegaRetail_Co") &
    (df["date"].dt.year == 2023) &
    (df["date"].dt.month >= 10) &
    (df["shipment_class"] == "standard")
].copy()

filt["zone"] = [zones.get(f"{o}_{d}", 3)
                for o, d in zip(filt["origin_city"], filt["destination_city"])]

totals = {}
for carrier, fn in FEE_FUNCS.items():
    std = sum(fn(r.weight_kg, r.zone, "standard") for r in filt.itertuples())
    exp = sum(fn(r.weight_kg, r.zone, "express")  for r in filt.itertuples())
    totals[carrier] = {"standard": std, "express": exp}

cheapest = min(totals, key=lambda c: totals[c]["express"])
diff = totals[cheapest]["express"] - totals[cheapest]["standard"]
answer = f"{cheapest}:{diff:.2f}"

with open("/app/answer.txt", "w") as f:
    f.write(answer + "\n")

print(answer)
