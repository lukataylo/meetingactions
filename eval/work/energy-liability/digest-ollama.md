## What this was about
The team discussed UI improvements for menu organization, specifically regarding the placement of data export links and currency field logic. They also discussed technical requirements for conditional logic in country/clause mapping and a requested "reject" feature for the producing broker portal.

## Actions I committed to
None.

## Proposed ADO items
- [ ] **Update currency field logic to support forced currency locking**, Task: Implement logic to ensure fields can only accept specific currency types when a condition is met.
- [ ] **Add "Reject" option for producing broker portal**, Product Backlog Item: Provide producing brokers with a way to reject a broker rather than just notifying them.
- [ ] **Investigate Power BI reporting for Cyber Plus**, Task: Determine if current reporting features are required for feature parity before adding more functionality to the deprecated system.
the recording, in case one is mine:

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
