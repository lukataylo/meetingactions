You are grading an action-extraction step. A meeting transcript was summarised into a
digest with "Actions I committed to" and "Proposed ADO items". Separately, a human
created these Azure DevOps work items within two days of that meeting:

EXPECTED
{{EXPECTED}}

DIGEST
{{DIGEST}}

For every expected item decide whether the digest proposes it:
- "yes"     — a proposal or action clearly covers the same change
- "partial" — the topic is there but scope or direction differs materially
- "no"      — nothing in the digest corresponds

Then list every digest proposal (from "Proposed ADO items") that matches none of the
expected items — these are extras, not necessarily wrong.

Answer with JSON only, no prose:
{"matches":[{"ticket":<id>,"verdict":"yes|partial|no","proposal":"<quote or empty>"}],
 "extras":["<proposal title>", ...]}
