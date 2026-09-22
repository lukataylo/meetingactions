## What this was about
The meeting focused on reviewing the "offline" market workflow, which allows brokers to complete the full flow from draft to binding without an underwriter present on the platform. The team also reviewed the "can submit" flag logic and the visibility of the NTU option for producing brokers.

## Actions I committed to
*   None.

## Proposed ADO items
- [ ] **Restore NTU option for producing brokers** (Product Backlog Item): Ensure the NTU option is visible and available for producing brokers to differentiate status in their risk list.
- [ ] **Update NTU/Notify logic for producing brokers** (Task): Adjust the UI so that producing brokers can see the NTU option but are restricted from using the "Accept" action.

## Open questions
*   Which specific notifications are currently skipped for producing brokers? (Referenced a Confluence list by Milan).
roker should be able to NTU and to notify the placing broker, but not accept. Currently NTU is unavailable, so "notify placing broker" has no clear meaning (decline or proceed?).
- [ ] **Producing broker risk list: show "sent for placing broker review" state** · Product Backlog Item · Risks that have been sent for placing broker review still show as Draft in the producing broker's risk list. Add the placing‑broker‑review indicator (currently only visible to the placing broker) so they can tell what is already actioned.

## Open questions

- Check Milan's Confluence list of which notifications the producing broker does and does not receive (offer made, firm order accepted, etc.).
- Confirm whether the producing broker used to see the firm order screen before the underwriter responds, and whether that should come back.
- Confirm that amendments, cancellations and other post‑bind steps for offline placements are actually scheduled, since only the draft‑to‑bound flow is covered today.
