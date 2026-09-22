## What this was about

A walkthrough of the new Facility Manager and Client Manager screens with the aviation team, checking what they can configure themselves and what still needs engineering. The conversation also covered the data export, chat log export, and the state of migrated line slip rules.

## Decisions and follow-ups

- Support restricting third-party access to specific line slips within a product, not just the whole product.
- Confirm producing brokers only ever see their own submissions.
- Fix navigation so users can return from Facility Manager to live xTrade without logging out and back in.
- Show country names instead of numeric codes in the country exclusion field and in exports.
- Set up direct insureds and reinsureds as clients in Client Manager, the same way as placing brokers.
- Make brokers pick the insured or reinsured from a dropdown when placing direct; no free-text entry.
- Provide a bulk upload for clients from a spreadsheet, including Hibble and Lux codes. James Mortimer may supply the codes.
- Produce a report showing which users and underwriters have access to each facility and who receives declaration copies.
- Explore having the MSCP onboarding team notify the xTrade team when a client clears compliance, so the client is set up immediately. Discuss with Jill or Paul Hilliard.
- Improve the data export: one row per aircraft with insured name, UMR and policy reference; currency in its own column separate from the amount.
- Add a per-risk chat log export in script format, downloadable from the risk itself.
- Provide a download of each facility's rules, such as max fixed wing, max rotary wing and brokerage, for reconciliation against the team's spreadsheet.
- Ems to review migrated line slips: rename them so reporting is correct and check the visibility rules.
- Ems to try the saved report and data export approach today and report back.
- Investigate why migrated rules on the Specialty MGA facility exist but do not display in Facility Manager.

## Proposed ADO items

- [ ] **Return to live xTrade from Facility Manager** · Bug · After opening Facility Manager there is no route back to the main xTrade dashboard, and re-authenticating returns the user to Facility Manager.
- [ ] **Migrated facility rules not visible in Facility Manager** · Bug · Rules migrated from xTrade 1 (e.g. max hull and liability limits) are applied but do not display on the facility's rules screen.
- [ ] **Restrict third-party access by line slip** · Product Backlog Item · Allow access for a third-party user to be limited to selected line slips within a product rather than the whole product.
- [ ] **Show country name instead of code** · Bug · Country exclusion fields and exports display the numeric country code (e.g. 76) rather than the name.
- [ ] **Insured and reinsured selection from client list on direct placements** · Product Backlog Item · When a placement is direct, the insured or reinsured must be chosen from Client Manager records via dropdown; manual text entry is not permitted.
- [ ] **Bulk client upload** · Product Backlog Item · Import clients from a spreadsheet, including GXB, Hibble and Lux codes, instead of creating them one by one.
- [ ] **Facility access and notification report** · Product Backlog Item · Downloadable report listing, per facility, which users and underwriters have access and who receives declaration emails.
- [ ] **Data export: one row per aircraft with policy identifiers** · Product Backlog Item · Aircraft schedule export includes insured name, UMR and policy reference on each row so aircraft data can be pulled from one source.
- [ ] **Data export: separate currency column** · Product Backlog Item · Export monetary values with the currency in its own column and the amount as a plain number.
- [ ] **Per-risk chat log export** · Product Backlog Item · Download the chat history for a single risk from the risk screen, formatted as speaker and message lines.
- [ ] **Facility rules download** · Product Backlog Item · Export each facility's configured rules (limits, brokerage, etc.) as a spreadsheet for review.
- [ ] **Client onboarding handoff notification** · Task · Agree a process with the MSCP onboarding team so that newly cleared clients are flagged for setup in xTrade without a separate request.

## Open questions

- Are the Hibble and Lux codes mandatory when creating a client, or only GXB?
- Who heads the MSCP team, and who owns the conversation about the onboarding handoff?
- What is going into this Thursday's release?
- Should the address lookup from xTrade 1 be revived in Client Manager, given it never worked well?
