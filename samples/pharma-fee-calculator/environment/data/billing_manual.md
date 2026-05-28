# Clinical Trial Billing Manual
## Version 4.2 — Effective January 2022

---

## 1. Introduction

This manual governs the calculation of service fees for clinical trial management
and regulatory support services provided to sponsor companies. All fees are
denominated in Euros (EUR) and calculated at the time of invoice generation.
Fee structures described herein apply to all active trials recorded in the billing
system unless otherwise stated in a sponsor-specific Master Service Agreement
(MSA). In the absence of an MSA override, the rules in this document take
precedence.

Billing operations staff are expected to apply these rules in sequence as described
in each section. Skipping any step will result in miscalculated invoices.

---

## 2. Base Fee Calculation

The foundation of every trial invoice is the **base fee**, which represents the
per-patient service cost agreed upon at trial initiation. The base fee is stored
as a per-patient EUR amount in the billing system field `base_fee_eur`.

The total base amount for any trial is:

    total_base = base_fee_eur × patient_count

This figure represents the gross billable amount before any therapeutic-area
adjustments, regulatory surcharges, or legacy fees are applied. Patient count
is taken from the trial registration record and is not adjusted mid-trial
unless a formal amendment is filed.

---

## 3. Therapeutic Area Adjustments

Clinical trials are classified by drug class (also referred to as therapeutic area).
Each class carries an adjustment multiplier that reflects the complexity of regulatory
oversight, data management requirements, and monitoring intensity typical of that
area. The multiplier is applied to the base fee amount calculated in Section 2.

The current multipliers by therapeutic area are as follows. Oncology trials, given
their complexity of endpoints and safety monitoring requirements, are billed at
one point three times the base amount. Cardiology trials, which involve a moderate
level of cardiac safety monitoring, are billed at one point one times the base amount.
Neurology trials are billed at the base amount with no adjustment, that is, a
multiplier of one point zero. Immunology trials, which require additional biomarker
panel management, are billed at one point two times the base. Rare disease trials
carry the highest multiplier of one point five, reflecting the small patient
populations, expanded access considerations, and disproportionate per-site overhead
that characterise these programmes.

To summarize: Oncology ×1.3, Cardiology ×1.1, Neurology ×1.0, Immunology ×1.2,
Rare Disease ×1.5. These multipliers apply before any regional adjustments
described in Section 5.

For the avoidance of doubt, the adjusted fee prior to surcharge is:

    adjusted_fee = total_base × therapeutic_multiplier

---

## 4. Phase IV Legacy Fee

Trials classified as Phase IV (post-marketing surveillance) are subject to a
flat administrative fee of €500 per trial, charged in addition to the standard
base fee and therapeutic area adjustment. This fee covers the additional
pharmacovigilance reporting obligations that apply to approved compounds. The
legacy fee is not subject to therapeutic area multipliers and is added as a
flat line item to the invoice after all other calculations are complete.

For billing purposes, Phase IV trials are identified by the value `Phase_IV` in
the trial phase field.

Note that this legacy fee is not applicable to Phase I, Phase II, or Phase III
trials. It also does not interact with regional surcharges — the legacy fee is
always a flat addition, regardless of country or ACI classification.

---

## 5. Regional Compliance Adjustments

Certain jurisdictions impose additional regulatory compliance obligations on
clinical trial sponsors, particularly during the pivotal trial phase. To cover
the increased administrative and legal overhead associated with operating in
these regions, a regional surcharge may be applied.

The European regulatory environment, governed by the EU Clinical Trials Regulation
(CTR) and associated national competent authority requirements, imposes the most
significant additional burden. Accordingly, a compliance surcharge applies to
trials conducted in EU member states — specifically those with country codes DE,
FR, NL, ES, and IT in the billing system — when such trials are in Phase III.

However, not all Phase III EU trials are subject to the surcharge. The surcharge
is only applicable where the trial's Authorization Characteristics Indicator
reflects a profile that requires enhanced submission packages. Specifically,
trials classified under ACI codes A, B, or C are subject to the surcharge, as
these represent novel molecular entities, accelerated approval pathways, and
conditional marketing authorization tracks respectively, all of which require
substantive additional regulatory work. Trials with ACI codes D or E are exempt,
as these cover biosimilar submissions and generic line extensions which operate
under streamlined regulatory pathways and do not generate the same compliance
overhead.

The current surcharge rate is **2.5%**, applied to the therapeutically-adjusted
fee (i.e., post-multiplier) for qualifying trials. The surcharge is therefore:

    surcharge = adjusted_fee × surcharge_rate    (qualifying trials only)
    total_fee  = adjusted_fee + surcharge

To qualify, a trial must simultaneously satisfy all three of the following:
it must be Phase III; it must be conducted in one of the five EU country codes
listed above; and its ACI code must be A, B, or C.

The surcharge does not apply to Phase I, Phase II, or Phase IV trials in any
jurisdiction. It does not apply to Phase III trials in non-EU countries. It does
not apply to Phase III EU trials where the ACI code is D or E. Only when all
three conditions are met is the surcharge charged.

---

## 6. Currency and Reporting

All fees in the billing system are denominated in EUR at point of entry. There
is no currency conversion step required. Historical records in legacy currencies
(GBP pre-2022, CHF for Swiss affiliates) were converted at the rates prevailing
at contract signature and are stored as EUR in the system. Any external reporting
in USD or GBP requires a separate FX conversion step performed by finance using
the ECB reference rates for the invoice date — this conversion is outside the
scope of the billing calculation covered here.

For reporting purposes, all fee totals should be rounded to two decimal places
at the final aggregation step, not at intermediate calculation steps. Premature
rounding will introduce small discrepancies in aggregate reports.

---

## 7. Aggregation and Reporting

When producing summary billing reports, fees should be grouped by the relevant
dimension (sponsor company, therapeutic area, trial phase, or geography) and
summed before rounding. The standard report format lists groups in ascending
order of total fee unless otherwise specified in the report request.

For delta analyses — comparing fee totals under two different rate assumptions —
the delta is defined as:

    delta = total_fee_new_rate − total_fee_old_rate

Deltas are reported at the group level (e.g., per therapeutic area) and are
presented in ascending order of delta magnitude unless otherwise specified.

---

## 8. Amendments and Retrospective Adjustments

Where a trial is amended after initial registration (change in phase, patient
count revision, country transfer), the billing record is updated and a credit or
debit note issued for the difference. The amended record governs; the original
record is archived. For the purposes of analytical queries against the billing
database, always use the current record values — the system does not expose
historical pre-amendment figures.

---

## 9. Contact and Escalation

For billing queries, contact the Regional Billing Operations desk. For disputes
exceeding €10,000 in a single invoice, escalation to the Head of Finance is
required before issuance of a credit note. All corrections require dual
sign-off.

---

*End of Billing Manual v4.2*
