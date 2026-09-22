## What this was about

A Monday standup where each team member gave a short update on what they finished and what they are picking up next. The 6.6 and 10.10 releases are on QA and being tested this week. The second half was a design discussion about where the audit log lives in the UI and what it shows, which settled on an entity-level view rather than a separate page.

## Decisions and follow-ups

- Put the audit log on the single-entity level (facility, client, etc.), not on a separate app-wide page.
- Keep recording delete events in the backend even though they will not appear in the entity-level view.
- Show creation and update entries with actor, action and time. Drop the entity type column since the user is already inside the entity.
- Restrict opening the audit log to admins, per the existing acceptance criteria.
- Confirm with Milan whether to build the audit trail now or after the database migration. Prepare the work either way so only the database switch remains.
- Chase a response on the migration plan.
- Apply David's changes to preferred languages per product and continue the implementation.
- Raise the PR for restrict editing to the lock holder, then move on to the UI tickets.
- Finish testing share custom report, then make the client company fix discussed on Friday.
- Agree with the config team how contract templates are stored in the new blob and how they are versioned.
- Work out how to hide conditions by role for auto document generation.
- Confirm the plan for the Acord external API.
- Release the 6.6 frontend once the outstanding pull requests are approved.
- Close out testing for 6.6 and 10.10 this week.
- Extend the cancellation automation suite with backdated cancellation.
- Finish the reference data add/edit form refactor, fix the UI and retest.
- Finish the Microsoft Defender cost research and continue fixing the integration function and service.

## Proposed ADO items

- [ ] **Entity-level audit log view** · Product Backlog Item · Add an admin-only audit log section on each entity page (stamps, facilities, clients, producing brokers) listing create and update entries with actor, action and timestamp, filterable by actor and date range.
- [ ] **Record delete events in the audit trail** · Task · Persist delete actions in the audit trail store so a record of removed entities exists even though it is not surfaced in the entity-level view.
- [ ] **Contract template storage and versioning in blob** · Task · Define the blob layout and versioning scheme for Docmosis contract templates and agree it with the config team.
- [ ] **Hide auto document generation conditions by role** · Product Backlog Item · Allow hidden conditions in auto document generation to be hidden based on the user's role.
- [ ] **Preferred languages per product: apply revised requirements** · Product Backlog Item · Update the preferred languages per product implementation to reflect the revised behaviour.
- [ ] **Backdated cancellation automation coverage** · Task · Extend the cancellation automation suite with backdated cancellation scenarios.

## Open questions

- Should the audit trail be implemented now or after the database migration?
- Is the migration plan approved as written, or does it need changes?
- Should the entity-level audit log show before and after values when an update touches many fields, or only the action summary?
- How exactly should hide-by-role work for auto document generation conditions?
- What is the next step and timeline for the Acord external API?
