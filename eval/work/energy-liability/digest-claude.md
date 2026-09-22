One caveat first: the recording was diarised into four speakers, and the only speaker addressed as "Luka" is not the one making the commitments below. I have assumed you are Speaker 1 and marked which speaker said each first-person commitment so you can strike anything that isn't yours.

## What this was about

Backlog triage across a few xTrade threads: whether to bolt a hosted HTML link onto the bottom menu now or wait for a proper menu redesign, locking a field's currency under a condition, whether Power BI reporting for Cyber Plus is worth extending given it may be deprecated, and negative or "none of the above" conditions for country-to-clause mappings. It closed with feedback from Energy Liability's end-to-end test: producing brokers can notify the placing broker but have no way to reject.

## Actions I committed to

As Speaker 1, I committed to nothing explicit. First-person commitments elsewhere in the recording, in case one is mine:

- Check whether Power BI reporting for Cyber Plus is required for feature parity before adding features to it (Speaker 3)
- Talk to Martina about CTIS requirements for negative conditions (Speaker 3)
- Tell Martina about the Energy Liability reject-option feedback and come back to Jack (Speaker 2)

## Proposed ADO items

- [ ] **Add hosted HTML page link to the bottom menu** · Task · Host the static HTML file and link it from the existing bottom menu alongside privacy and cookie policy, without touching the wider menu layout.
- [ ] **Redesign bottom menu hierarchy and give data export its own page** · Product Backlog Item · Separate items that sit at different levels in the bottom menu and move data export to a dedicated page with its own menu entry. Parked until sized; skip if over three points.
- [ ] **Lock a field's currency under a condition while leaving the amount editable** · Product Backlog Item · Allow a condition to fix the currency of one or more amount fields, mirroring reference-list locking for enums, so totals across multiple fields cannot mix currencies.
- [ ] **Support negative and "none of the above" conditions** · Product Backlog Item · Allow a condition to fire when a value is not any of a listed set, is none of the other conditions, or is blank, so country-to-clause mappings do not need every other country listed.
- [ ] **Clauses set by a condition are not cleared when the trigger value changes** · Bug · When a country such as Malta triggers clauses and the user then selects a country that matches no condition, the Malta clauses remain on the form instead of being removed.
- [ ] **Add a reject option for producing brokers** · Product Backlog Item · Give the producing broker a way to reject a placement they do not want to take up, in addition to the existing notify action to the placing broker.

## Open questions

- Is Power BI reporting for Cyber Plus needed for feature parity, or is it being deprecated and not worth adding features to?
- What has Martina found on CTIS needing negative conditions? Is this a must-have rather than nice-to-have?
- Is the producing-broker reject option a must-have for Energy Liability or a nice-to-have? They flagged it as something they thought was a mistake.
- Is the menu redesign more than a three-pointer? If so, it stays parked.
- Do any of the customers discussed have bespoke MSAs?
