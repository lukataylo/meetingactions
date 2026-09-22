## What this was about

A walkthrough on dev of the new offline-insurer flow in xTrade. When an insurer is flagged offline in Entity Manager, the broker fills in the offer, accepts it, requests and accepts the firm order, and binds, with evidence upload enforced before completing placement. Amendments and cancellations are out of scope for now, and the release is planned for Thursday.

Note on attribution: the diarised speakers do not line up cleanly with "my" mic. The person addressed as Luka appears mostly off-mic, and the only lines plausibly mine are short acknowledgements. The questions about toggles, facility members and offline followers were asked by the QA lead (addressed as Dora), and the sidebar suggestion came from the same person.

## Actions I committed to

I committed to nothing explicit in the recorded half. My audible contributions are limited to acknowledgements.

## Proposed ADO items

None.

For your awareness, two things were raised by others that you may still want to file:
- Keep the offer sidebar open after the status changes to Offered and after firm order acceptance, instead of closing and forcing a second click.
- Collapse the offline toggle to insurer level only, since an insurer offline at facility-member level but online elsewhere has no use case.
