## What this was about

A walkthrough on dev of the new offline insurer placement flow. When an insurer is flagged offline in Entity Manager, the broker fills in the underwriter's side themselves: offer, firm order, evidence upload and bind. Amendments and cancellations are out of scope for this release, which goes out Thursday.

## Decisions and follow-ups

- Keep the sidebar open after the broker moves a contract to Offered or accepts a firm order, instead of closing it and forcing a reopen.
- Keep the offline flag at insurer level only. Drop the facility member level toggle in Entity Manager.
- Make it clearer in the offer sidebar that evidence upload is required before bind. Today it only surfaces as an error at bind.
- Handle amendments and cancellations for offline insurers in a later release.
- Run the offline flow end to end as a team next week before demoing. Nothing before then as Alex is off at the end of this week.
- Test coverage stays on the straightforward placement path for now, driven from the Entity Manager toggle with no extra config.

## Proposed ADO items

- [ ] **Keep sidebar open after offline placement status changes** — Product Backlog Item — After a broker submits an offer or accepts a firm order on an offline placement, reload with the sidebar still open rather than closing it.
- [ ] **Remove facility member level offline toggle** — Task — Offline is an insurer level setting. Remove the duplicate toggle on facility members in Entity Manager so only the insurer flag drives the behaviour.
- [ ] **Show evidence upload as required before bind on offline placements** — Product Backlog Item — Mark the evidence upload step as mandatory in the offer sidebar so brokers see it before hitting the bind error.
- [ ] **Amendments and cancellations for offline insurers** — Product Backlog Item — Extend the broker driven offline flow to cover amendments and cancellations after bind.

## Open questions

- Can a single placement mix online and offline markets, for example one panel online and another offline? This depends on the separate panels work.
- Is there any real use case for an offline follower or auto follower, or should followers always be online?
