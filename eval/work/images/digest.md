One note before the draft: this transcript is diarized into thirteen speakers, so it reads as the whole room rather than one mic. People address you as Luca, and your own captured lines are only the welcome at the start, so almost nothing below is attributed to you.

## What this was about

Monday standup for the xTrade team. Everyone gave their status: preferable languages per product, the database migration plan, restrict-editing-to-lock-holder, share custom report, the contract API and Docmosis templates, the 6.6 and 10.10 releases, QA automation, reference data forms, and Microsoft Defender costs. The last part was a design discussion on the audit log UI, where the group settled on keeping it at the single-entity level, admin only, showing create and update but not delete in the UI, with delete still recorded in the backend.

## Actions I committed to

None recorded. The only thing that looks like an implicit commitment is talking to the developer working on preferable languages and audit logs later today about their audit log questions, but your side of that exchange was not captured.

## Proposed ADO items

None. The audit log changes discussed (drop delete from the UI, drop the entity type filter on the entity-level view, keep before and after values) belong to the audit log implementer and Darko, not to you.
