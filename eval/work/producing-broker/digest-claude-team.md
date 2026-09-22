## What this was about

A pre-release walkthrough on QA of two features. First, the producing broker flow with the can-submit flag set to false, where the producing broker can only notify the placing broker and complete placement. Second, offline placements, where an insurer marked offline never touches the platform and the broker fills in the offer and firm order responses themselves, with mandatory offline market evidence before binding.

## Decisions and follow-ups

- Restore the NTU (not taken up) action for producing brokers with can-submit false, while keeping accept disabled.
- Show a "placing broker review" indicator in the producing broker's risk list so sent risks are distinguishable from drafts.
- Ship the producing broker restrictions as they stand for this release; the NTU change follows after.
- Extend offline placements to amendments, cancellations and post-bind actions in a later iteration.
- Check the Confluence notification list to confirm which notifications producing brokers receive.

## Proposed ADO items

- [ ] **Producing broker can NTU but not accept when can-submit is false** | Product Backlog Item | On an offered or firm-ordered risk, a producing broker with can-submit false sees NTU and Notify placing broker as the only actions; accept stays hidden.
- [ ] **Placing broker review indicator on producing broker risk list** | Product Backlog Item | After a producing broker sends a risk for placing broker review, show the same review status icon in their risk list that the placing broker sees.
- [ ] **Offline placements: post-bind flows** | Product Backlog Item | Support amendments, cancellations and other post-bind actions for placements where the lead or a follower is an offline insurer.

## Open questions

- Which notifications should the producing broker receive, and does the current behaviour match the Confluence list?
- Should the producing broker be able to see the firm order before the underwriter responds, as they reportedly could previously?
- Does any current client want to use offline placements right away?
