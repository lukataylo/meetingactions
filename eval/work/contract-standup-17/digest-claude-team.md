## What this was about

Daily standup for the xTrade team. Each person gave a short update on yesterday's work and today's plan. The morning production release went out cleanly and automated tests passed, so most of the conversation was about in-flight work: ACORD mapping, audit trail, permissions, .NET 10 migration, and PR reviews.

## Decisions and follow-ups

- Watch production logs through the day after the morning release to UAT, sandbox and production.
- Merge the dotted trail draft PR to dev once the dependent work is merged and tested.
- Move focus to file attachments.
- Confirm with Jasper whether any ACORD mapping syntax currently out of scope is needed for insurers now.
- Chase Simran for a reply on the contract that needs updating.
- Apply the prepared fix for the Housen Scotland producing brokers contract once confirmed it was missed.
- Continue the .NET 8 to .NET 10 transition.
- Keep the migration documentation on hold until Zerko has discussed it with the other part of the team.
- Source xTrade entities in the contract API from the entity manager.
- Review the two open audit trail PRs.
- Finish the permissions spike: backend design first, then frontend.
- Open the conditional required fields PR as a draft and agree the JSON schema change for required fields.
- Open the PR for comparison metrics.
- Review the sale reports PR and the three other pending PRs.
- Test the remaining tickets manually in QA.
- Support big table collections in the builder.
- Pick up incoming service desk tickets.

## Proposed ADO items

- [ ] **Update producing brokers contract for Housen Scotland** — Bug — The producing brokers contract for Housen Scotland is missing or out of date and needs the prepared correction applied.
- [ ] **Support conditional required fields in product definitions** — Product Backlog Item — Extend the JSON schema and validation so a field can be required only when a condition on another field is met.
- [ ] **Comparison metrics** — Product Backlog Item — Expose comparison metrics for placements so users can compare offers side by side.
- [ ] **File attachments on placements** — Product Backlog Item — Allow users to attach files to a placement and view them from the placement screen.
- [ ] **Support big table collections in the builder** — Product Backlog Item — Let the product definition builder create and edit large table collections without degrading the editing experience.
- [ ] **Migrate services from .NET 8 to .NET 10** — Task — Upgrade the target framework across services, fix breaking changes, and verify builds and tests pass.
- [ ] **Permissions model spike** — Task — Design the backend and frontend approach for the new permissions model and document the recommended option.
- [ ] **ACORD mapping: confirm remaining syntax scope** — Task — Decide which unsupported ACORD mapping syntax items are needed for current insurers and implement those.

## Open questions

- Is the contract update Simran was asked about still needed, and is the Housen Scotland contract genuinely missing or was it never provided?
- How should the JSON schema change to express conditional required fields?
- What is the agreed migration approach, pending Zerko's discussion with the rest of the team?
- Which ACORD syntax items stay out of scope for the current insurers?
