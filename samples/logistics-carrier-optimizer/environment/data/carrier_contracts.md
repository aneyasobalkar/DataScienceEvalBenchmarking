# Carrier Service Contracts and Fee Schedule
## MegaRetail_Co — Logistics Partner Agreement Summary
### Effective 1 January 2023 — Reference Document v3.1

---

## 1. Purpose and Scope

This document summarises the commercial terms agreed between MegaRetail_Co and its
approved carrier panel for the 2023 contract year. It is intended as an operational
reference for billing reconciliation and scenario modelling. All fees are denominated
in Euros (EUR). Fees apply per shipment at the time of despatch booking and are
calculated using the rules described below. In all cases the zone classification
(see Appendix — zones.json) must be resolved before fee computation, as zone is an
input to every base rate formula.

---

## 2. FastShip — Contract Terms

FastShip operates a zone-weighted, weight-sensitive pricing model for standard
parcels. The per-kilogram rate for standard service is determined by multiplying
the shipment zone by a fixed coefficient of 2.50 EUR. That is, a zone-3 shipment
of any weight is billed at 7.50 EUR per kilogram under standard terms. The total
standard fee is simply this per-kilogram rate applied to the actual shipment weight.

FastShip offers a volume-adjusted pricing benefit for heavier consignments. For any
shipment exceeding twenty kilograms, the per-kilogram rate receives a fifteen percent
reduction. This reduction is applied to the per-kilogram figure computed from the
zone before any service-class uplift is considered. The discounted per-kilogram rate
is then used as the basis for all further calculations on that shipment.

For shipments upgraded or reclassified to express service, FastShip applies an
express uplift factor of one point eight to the fee as calculated above — that is,
the full cost including any weight break adjustment is multiplied by one point eight.
There are no additional flat fees or surcharges for express service under this
contract. FastShip does not apply fuel surcharges, zone premiums, or handling fees
to any service class.

To summarise FastShip computation order: (1) establish per-kg rate from zone × 2.50;
(2) apply fifteen percent discount if weight exceeds twenty kilograms; (3) multiply
discounted per-kg rate by actual weight; (4) for express, multiply the result by 1.8.

---

## 3. ReliableExpress — Contract Terms

ReliableExpress uses a similar zone-weighted structure but at a higher base coefficient,
reflecting their premium network coverage and transit time guarantees. The standard
per-kilogram rate is the shipment zone multiplied by 3.00 EUR. A zone-4 standard
shipment is therefore billed at 12.00 EUR per kilogram, regardless of weight, before
any adjustments.

ReliableExpress provides a weight-tiered discount for consignments above fifteen
kilograms. When the shipment weight exceeds this threshold, the per-kilogram rate
is reduced by ten percent. As with FastShip, this reduction is applied to the base
per-kilogram figure derived from the zone, before any service-class multiplier is
introduced. The weight-adjusted per-kilogram rate then serves as the starting point
for further calculation.

For express-classified shipments, ReliableExpress applies a service multiplier of
one point five to the fee derived from the weight-adjusted base rate. In addition,
a fuel and priority surcharge of 2.50 EUR is levied as a flat amount per shipment
for all express consignments, regardless of zone, weight, or destination. This flat
surcharge is added after the multiplier has been applied. It does not appear on
standard-class shipments.

To summarise ReliableExpress computation order: (1) per-kg rate = zone × 3.00;
(2) apply ten percent discount if weight exceeds fifteen kilograms; (3) multiply
discounted per-kg rate by actual weight; (4) for express, multiply by 1.5 then
add the flat 2.50 EUR surcharge. Standard shipments incur no surcharge.

---

## 4. BudgetFreight — Contract Terms

BudgetFreight offers the lowest base coefficient in the panel at 2.00 EUR per kilogram
per zone unit. The standard fee for any shipment is zone multiplied by 2.00, then
multiplied by the shipment weight in kilograms. BudgetFreight does not offer weight
break pricing at any threshold; the per-kilogram rate is uniform across all weight
bands under both standard and express service.

For express service, BudgetFreight applies a premium multiplier of two point two to the
base fee. This reflects the additional network prioritisation cost for their typically
economy-oriented infrastructure. The absence of weight breaks means the fee scales
linearly with weight at all times.

BudgetFreight is the only carrier in the panel that applies a handling fee to all
shipments, irrespective of service class or destination. A handling charge of one
point five percent is applied to the computed shipment fee — whether that fee is
the standard base amount or the express-multiplied amount — as a final step in
the fee calculation. This handling fee is not waivable and applies to every
consignment without exception, including overnight and freight classes not
discussed here.

To summarise BudgetFreight computation order: (1) base = zone × 2.00 × weight;
(2) for express, multiply by 2.2; (3) always add 1.5% handling fee to the result
regardless of service class.

---

## 5. PrimeLogistics — Contract Terms

PrimeLogistics operates a four-element fee model that rewards high-volume, long-haul
shippers but carries zone-specific premiums for premium service. The standard
per-kilogram rate is zone multiplied by 2.75 EUR. For a zone-5 standard shipment,
this yields 13.75 EUR per kilogram before weight adjustments.

PrimeLogistics offers the most generous weight break in the panel, applicable to
shipments exceeding twenty-five kilograms. When the weight threshold is crossed, the
per-kilogram rate is discounted by twenty percent. This discount is calculated on
the zone-derived per-kilogram rate and applied before any express uplift factor is
introduced. The twenty-percent-reduced per-kilogram rate then becomes the operative
rate for all further fee computation on that shipment.

For express shipments, PrimeLogistics applies an uplift factor of one point six to
the fee computed from the weight-adjusted base rate. In addition, shipments routed
through zones four or five — that is, longer-haul corridors — carry an additional
flat surcharge of 5.00 EUR per shipment when classified as express. This surcharge
reflects the incremental priority handling cost on long-haul lanes and is only
incurred for express service; it does not apply to standard shipments in any zone.
Shipments in zones one, two, or three are not subject to this zone premium even
under express classification.

To summarise PrimeLogistics computation order: (1) per-kg rate = zone × 2.75;
(2) apply twenty percent discount if weight exceeds twenty-five kilograms;
(3) multiply discounted per-kg rate by actual weight; (4) for express, multiply
by 1.6; (5) for express in zones 4 or 5, add flat 5.00 EUR surcharge. Standard
shipments incur no surcharge and no zone premium.

---

## 6. Zone Reference

Shipment zones are defined by origin–destination city pair and stored in the
supplementary file zones.json. Zone values range from 1 (shortest routes, same
metropolitan area or adjacent city) to 5 (transcontinental corridors). Zone is
always resolved from the lookup before applying any fee formula. In the event
that a city pair is not present in zones.json, a default zone of 3 applies.

---

## 7. Cross-Carrier Comparison Notes

When performing carrier cost comparisons or hypothetical reclassification analyses,
all four carriers must be evaluated independently using their respective rule sets.
The weight break thresholds differ across carriers (15 kg for ReliableExpress, 20 kg
for FastShip, 25 kg for PrimeLogistics, none for BudgetFreight), as do the express
multipliers (1.5 to 2.2) and the presence or absence of flat surcharges. An analysis
that applies a single uniform multiplier to all carriers will produce incorrect
rankings, particularly for high-weight, long-haul shipment profiles where the
interaction between weight discounts and express multipliers creates non-obvious
ordering reversals.

---

## 8. Billing Disputes and Amendments

All billing queries must reference the contract year document version in use at the
time of the shipment. This document (v3.1) governs all 2023 shipments. Retrospective
amendments require written sign-off from both parties. Cost comparisons and scenario
analyses using these rates are considered indicative only and do not constitute a
binding quotation.

---

*End of Carrier Contract Reference v3.1*
