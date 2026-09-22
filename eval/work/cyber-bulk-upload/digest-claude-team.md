## What this was about

Daily stand-up for the xTrade team. Updates covered localisation of product definitions, the email notification flow, bulk upload, insurer and MarketLake integrations, Docmosis, and QA progress. The main new issue was a date parsing regression that breaks template ingestion and bulk upload, plus some planning around a stakeholder walkthrough and a visitor itinerary.

## Decisions and follow-ups

- Raise a bug ticket for the Excel date fix that only covered export and now rejects valid dates in template ingestion and bulk upload.
- Fix the date bug separately and before merging bulk upload, so both land in the next release. Theodora to test.
- Hold the 652 hotfix until the date ingestion regression is fixed. Add a comment or new ticket to the hotfix.
- Merge bulk upload once the date fix is in.
- Do a final review and manual test of the email notification flow, then close it.
- Discuss the contract API offer mappings with Chad.
- Refine the Power BI dashboard ticket so it can be picked up.
- Create a ticket to check duplicates only within the company or division access scope, not the whole product.
- Decide what to do with tomorrow's cyber project meeting, since Harry and Naomi are off.
- Set up a separate walkthrough call with the stakeholder team next week ahead of end of September.
- Confirm Martina and Melissa's itinerary tomorrow, including a walk leaving the office around 16:15 on Tuesday or Wednesday.
- Prioritise the document generation issue Simran raised.
- Publish the offers to market lines mapping PR after minor changes.
- Run the spike on the MarketLink API for GXB party UIDs and validation.
- Chase James for sign-off on the new GXB payload and J for the insurer callback setup.
- Finish document groups on the dev side today and test today or tomorrow.
- Open a PR for the renewal flow automated tests once the run passes.
- Resolve conflicts and PR the search-by-ID work, then pick up the reference data ID ticket.
- Continue with restricting everything to the log folder.
- Continue documentation for the entity manager database migration.

## Proposed ADO items

- [ ] **Valid dates rejected in template ingestion and bulk upload** | Bug | The shared date parsing method changed for the Excel export fix now returns errors for valid dates in the template ingestion and bulk upload flows. Fix the shared method and add regression coverage for all three callers.
- [ ] **Scope duplicate checks to company and division access scope** | Product Backlog Item | Duplicate detection currently runs across the whole product. Restrict it to records within the user's company or division access scope.
- [ ] **Hotfix 652 blocked on date ingestion regression** | Task | Verify the date field ingestion regression is resolved and retested before releasing hotfix 652.

## Open questions

- Is the 652 hotfix urgent enough to pull someone off the document generation issue?
- Does tomorrow's cyber project meeting go ahead, get moved, or get cancelled?
- Who from the stakeholder team joins the walkthrough next week, and when?
- Does the team have capacity for the additional parity service that was raised?
- Tuesday or Wednesday for the visitors' walk, depending on weather?
