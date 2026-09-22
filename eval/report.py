import json, glob, os, collections
cases = {c["id"]: c for c in json.load(open("cases.json"))}
rows, totals = [], collections.defaultdict(lambda: [0.0, 0, 0])   # sm -> [score, n, extras]
for f in sorted(glob.glob("results/*.json")):
    cid, sm = os.path.basename(f)[:-5].rsplit("-", 1)
    try: r = json.load(open(f))
    except Exception: rows.append((cid, sm, "judge failed", "", "")); continue
    score = sum({"yes": 1, "partial": 0.5}.get(m["verdict"], 0) for m in r["matches"])
    n = len(cases[cid]["tickets"]); ex = len(r.get("extras", []))
    totals[sm][0] += score; totals[sm][1] += n; totals[sm][2] += ex
    misses = ", ".join(str(m["ticket"]) for m in r["matches"] if m["verdict"] == "no")
    rows.append((cid, sm, f"{score:g}/{n}", ex, misses))
with open("results/report.md", "w") as out:
    out.write("# Digest → ticket recall\n\nGround truth: tickets the user filed within two days of a Trace-recorded meeting.\n")
    out.write("Score: yes = 1, partial = 0.5. Extras = proposals matching no filed ticket (not necessarily wrong).\n\n")
    out.write("| case | summariser | recall | extras | missed |\n|---|---|---|---|---|\n")
    for cid, sm, sc, ex, mi in rows: out.write(f"| {cid} | {sm} | {sc} | {ex} | {mi} |\n")
    out.write("\n| summariser | recall | extras/case |\n|---|---|---|\n")
    for sm, (s, n, ex) in totals.items():
        k = sum(1 for r in rows if r[1] == sm)
        out.write(f"| {sm} | {s:g}/{n} = {s/n:.0%} | {ex/k:.1f} |\n" if n else "")
print(open("results/report.md").read())
