## What this was about

A walkthrough of Facility Manager and Client Manager with Emma and Alex, to pin down what they can do themselves and where it falls short. It covered third-party access restriction, setting up insureds and reinsureds as clients, the data export, and the migrated line slip rules.

Note: the transcript labels are Emma, Alex and a third voice. Almost none of Luca's own lines were captured, so commitments below are only what was clearly handed to me.

## Actions I committed to

Nothing explicit from me was captured. Things clearly left with me:

- Take away the idea of MSCP onboarding triggering client set-up in xTrade (from Alex). Alex said "I will leave that with you too".
- Provide Emma and Alex a download of who has access and who receives copy declarations, per facility, for users and underwriters. Emma asked; my answer is missing.
- Provide Emma a download of facility rules (max fixed wing, max rotary wing, brokerage) per line slip so she can compare against her spreadsheet. Emma asked; my answer is missing.

## Proposed ADO items

- [ ] **No route back from Facility Manager to xTrade live** · Bug · After opening Facility Manager there is no way back to the main dashboard. Logging out and back in, including re-authentication, returns the user to Facility Manager rather than xTrade.
- [ ] **Migrated line slip rules not visible in Facility Manager** · Bug · Rules migrated from xTrade 1 (for example the max hull and liability limits on a specialty MGA line slip) exist and are applied, but the rule editor shows only the operator with no value.
- [ ] **Show country names instead of numeric codes** · Bug · Country exclusions in Facility Manager and the country column in the data export show numeric codes (for example 76) rather than the country name.
- [ ] **Restrict third-party access to specific line slips** · Product Backlog Item · Third-party brokers given access to a product should be limited to named line slips, not all lines under that product. They should still see only their own submissions.
- [ ] **Insured and reinsured selected from Client Manager on direct risks** · Product Backlog Item · Where a risk is direct, the insured or reinsured must be picked from a drop-down of clients set up in Client Manager, with no free-text entry. Clients carry GXB, Hibble and Lux codes as for placing brokers.
- [ ] **Bulk upload of clients** · Product Backlog Item · Allow clients to be loaded into Client Manager from a spreadsheet, including GXB, Hibble and Lux codes, instead of one at a time.
- [ ] **Access and distribution report per facility** · Product Backlog Item · Downloadable report listing, per facility, which users and underwriters have access and which receive declaration copies.
- [ ] **Facility rules report** · Product Backlog Item · Downloadable report listing each facility with its rules, such as max fixed wing, max rotary wing and brokerage, for reconciliation against business records.
- [ ] **Data export: one row per aircraft with policy details** · Product Backlog Item · Aircraft schedule export should give one row per aircraft with insured name, UMR and policy reference on each row. Currency code and amount should be in separate columns. Selected options should not spill into extra columns.
- [ ] **Export chat log at risk level** · Product Backlog Item · Download the chat for a single risk as a script-style transcript (speaker and message) from the risk itself, without going through the data export.
- [ ] **Client set-up triggered by onboarding completion** · Task · Agree a process with the MSCP onboarding team so that when a new client clears compliance, a request goes to the xTrade team to set them up straight away.

## Open questions

- Can third-party access be limited to specific line slips today, or only to a product?
- Are the Hibble and Lux codes mandatory when creating a client?
- Who heads the MSCP onboarding team (Jill or Paul Hilliard) to discuss the onboarding-to-xTrade handoff?
- Alex mentioned a Petiting Manager as the Strapi replacement. Confirm what was meant.
- Confirm what goes into this Thursday's release for Emma and Alex.
