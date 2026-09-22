## What this was about

A team session on the amendments redesign in xTrade: how agreement parties get picked at endorsement time, whether each amendment type needs its own dynamic form, and how to stop the risk form and the new amendment form both being places to edit the same fields. The second half covered the stale "multiple leads" spike and what clients actually mean by it, ending with a plan to workshop it with Alex.

## Decisions and follow-ups

- Pick agreement parties from all agreement parties at endorsement time, not by pre-configuring per-amendment-type insurers at bind.
- Skip the agreement-party pick and go straight to the lead when there is only one facility or the simplified workflow is in use.
- Keep extension, void, cancellation and capacity as separate configurable definitions rather than a fixed modal, since pricing and reasons vary per product.
- Model amendment definitions as children of the product definition: same field IDs, copied fields, plus type-specific extras, so changes map back to the contract by ID.
- Build a mechanism to propagate product definition field changes into the child amendment definitions when a version is bumped.
- Consider a product builder feature to generate amendment definition JSON from the product definition.
- Confirm that separate JSON files per amendment type work with placeholders and document generation the same way offers do.
- Hold a call with the config team on field-locking use cases and what gets mapped to the amendment form.
- Rework the summary-of-changes diff if the contract form is locked during amendments, since the diff is currently driven from the contract form.
- Re-walk the full amendment flow to pin down which fields change via the amendment form versus the risk form.
- Break the amendment work down per amendment type and assign an owner.
- Later: let manual follower underwriters participate in the amendment flow.
- Book a session with Alex next week (Mon to Wed) on multiple leads and verticalisation, and invite Goran.
- Prepare options and visual mock-ups of where multiple leads are added and how they display, ahead of that session.
- Update the multiple-leads spike after the session with what was learned.

## Proposed ADO items

- [ ] **Select agreement parties at endorsement time** · Product Backlog Item · When creating an endorsement, let the broker pick from all agreement parties on the contract. Skip the picker and route to the lead when there is a single facility or the simplified workflow applies.
- [ ] **Per-type amendment definitions inheriting from product definition** · Product Backlog Item · Introduce separate definition JSON files for cancellation, extension, void, capacity and endorsement. Each copies the product definition fields with matching IDs and may add type-specific fields, locks and conditions.
- [ ] **Propagate product definition changes to amendment definitions** · Task · When a product definition version adds or removes a field, apply the same change to every child amendment definition on version bump.
- [ ] **Generate amendment definition JSON from product builder** · Product Backlog Item · Add a product builder action that scaffolds an amendment definition from the current product definition fields.
- [ ] **Summary of changes driven by amendment definition** · Product Backlog Item · Compute the pre-submit change summary by matching field IDs between the amendment definition and the contract, so it still works when the contract form is locked.
- [ ] **Field locking rules across contract and amendment forms** · Task · Define and implement which fields are editable on the contract form versus the amendment form during an amendment, so a field cannot be changed in two places.
- [ ] **Manual follower underwriters in the amendment flow** · Product Backlog Item · Allow underwriters on manual follower lines to be asked to agree amendments, not just leads and facility parties.
- [ ] **Options for multiple leads and per-lead security panels** · Task · Document how leads, followers and panels behave today and propose UI flow options for more than one accepted lead, each with its own panel and followers.

## Open questions

- Does the current cancellation flow stay as it is, or move onto the new amendment definitions?
- Should the amendment types live in one definition file or one file each?
- Which fields are amendable only on the amendment form, and which stay editable on the risk form?
- Do clients want several accepted leads at once, each with their own followers and panel, or only multiple lead offers with one accepted?
- How does the new requirement differ from facilities that already list two leads, such as Starr and Lancashire?
