# Digest → ticket recall

Ground truth: tickets the user filed within two days of a Trace-recorded meeting.
Score: yes = 1, partial = 0.5. Extras = proposals matching no filed ticket (not necessarily wrong).

| case | summariser | recall | extras | missed |
|---|---|---|---|---|
| offline-placements | claude | 0/2 | 0 | 287960, 287961 |
| offline-placements | ollama | 0/2 | 1 | 287960, 287961 |

| summariser | recall | extras/case |
|---|---|---|
| claude | 0/2 = 0% | 0.0 |
| ollama | 0/2 = 0% | 1.0 |
