## What this was about

A QA walkthrough of two features. First, the producing broker flow with the can‑submit flag off: the producing broker can only notify the placing broker, and everything else (sanctions, send to leads, accept, firm order) sits with the placing broker. Second, offline placements: an insurer can be flagged offline, and the broker then fills in the submission response, firm order response and evidence themselves, all the way to bound, with no underwriter on the platform.

## Actions I committed to

I committed to nothing. I gave feedback that the producing broker flow is fine to go live with as is, and raised two changes I want made (below).

## Proposed ADO items

- [ ] **Producing broker: restore NTU on offered risks, keep Accept disabled** · Product Backlog Item · When the can‑submit flag is false and a risk is in Offered, the producing broker should be able to NTU and to notify the placing broker, but not accept. Currently NTU is unavailable, so "notify placing broker" has no clear meaning (decline or proceed?).
- [ ] **Producing broker risk list: show "sent for placing broker review" state** · Product Backlog Item · Risks that have been sent for placing broker review still show as Draft in the producing broker's risk list. Add the placing‑broker‑review indicator (currently only visible to the placing broker) so they can tell what is already actioned.

## Open questions

- Check Milan's Confluence list of which notifications the producing broker does and does not receive (offer made, firm order accepted, etc.).
- Confirm whether the producing broker used to see the firm order screen before the underwriter responds, and whether that should come back.
- Confirm that amendments, cancellations and other post‑bind steps for offline placements are actually scheduled, since only the draft‑to‑bound flow is covered today.
