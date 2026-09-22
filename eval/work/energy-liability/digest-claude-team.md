## What this was about

A whole-team catch-up covering several small product decisions. The group agreed to add a hosted HTML link to the footer menu now and park the wider menu redesign, discussed two gaps in the conditional rules engine (currency locking and negative conditions), flagged a Cyber Plus reporting feature that may be on a deprecated path, and heard end-to-end testing feedback from Energy Liability about the producing broker portal.

## Decisions and follow-ups

- Add the hosted HTML file as a link in the bottom menu now, as a standalone change separate from any menu redesign.
- Do not do the bigger menu redesign if it is more than a three-pointer. Keep the ticket captured for later.
- Revisit later: give data export its own page and possibly its own menu item.
- Add a conditional rule that locks a field's currency while still allowing the amount to be entered, mirroring the reference list restriction used for enums. Do it alongside the current currency work and testing.
- Investigate whether the Power BI reporting feature for Cyber Plus is needed for feature parity before adding to it, since that reporting is expected to be deprecated.
- Support negative conditions in rules, such as "not any of these" and "none of the above", plus a blank case.
- Fix conditionally-applied clauses staying in place after the user changes the trigger field to a value that no longer matches.
- Talk to Martina about CTIS requirements for negative conditions, since this may be needed rather than nice-to-have.
- Pass the Energy Liability feedback about a producing broker reject option to Martina and follow up with Jack.

## Proposed ADO items

- [ ] **Add hosted HTML page link to footer menu** — Task — Host the HTML file and link to it from the bottom menu alongside the existing policy links.
- [ ] **Redesign footer menu and give data export its own page** — Product Backlog Item — Separate items that sit at different levels in the bottom menu, keep privacy and cookie policy in the footer, and move data export to a dedicated page with its own menu entry. Parked until prioritised.
- [ ] **Conditional currency lock on amount fields** — Product Backlog Item — Allow a rule to lock a field's currency to a specific value under a condition while leaving the amount editable, so multi-field totals cannot mix currencies.
- [ ] **Negative and blank conditions in rule mappings** — Product Backlog Item — Allow conditions of the form "not any of these", "none of the above conditions", and "value is blank", so catch-all clause mappings do not require listing every other option.
- [ ] **Conditionally-added clauses persist after trigger no longer matches** — Bug — When a rule adds clauses based on a field value, such as a country, and the user then changes that field to a non-matching value, the clauses remain. Expected: they are removed or re-evaluated.
- [ ] **Spike: Power BI reporting for Cyber Plus feature parity** — Task — Confirm whether the Cyber Plus Power BI reporting capability is required for feature parity and whether building on it is the fastest route, given its planned deprecation.
- [ ] **Reject option for producing broker** — Product Backlog Item — Give the producing broker a way to reject a placement they do not want to take, in addition to the existing notify action for the placing broker.

## Open questions

- Whether a first-time modal on joining is wanted, and whether any clients have bespoke MSAs that would affect it.
- Whether the Cyber Plus Power BI reporting feature is required for feature parity, or whether effort should go elsewhere.
- Whether negative conditions are a hard requirement for CTIS. Depends on what Martina has found.
- Whether the producing broker reject option is a must-have. Energy Liability presented it as an apparent mistake during testing rather than a stated requirement.
