#!/bin/bash
# Eval: does the digest step propose the tickets a human actually filed after the meeting?
# Ground truth = Trace transcripts × ADO items created by the user within two days (cases.json).
# Read-only against ADO; nothing is filed.
set -uo pipefail
cd "$(dirname "$0")"
S="$HOME/Library/Containers/info.traceapp.trace/Data/Library/Application Support/Trace/sessions"
CLAUDE="$HOME/.local/bin/claude"
SUMMARISERS="${SUMMARISERS:-ollama claude claude-team}"   # claude-team = whole-call prompt, see team-prompt.md
JUDGE_PROMPT=$(cat judge.md)

n=$(jq length cases.json)
for ((i = 0; i < n; i++)); do   # indexed, not a stdin pipe: child processes cannot eat the case list
  row=$(jq -c ".[$i]" cases.json)
  id=$(jq -r .id <<<"$row"); session=$(jq -r .session <<<"$row")
  dir="work/$id"; mkdir -p "$dir"
  # strip Trace's title/date header; keep speaker-labelled lines
  grep -v '^#\|^_' "$S/$session/transcript.md" | sed '/^$/d' > "$dir/transcript.txt"
  expected=$(jq -r '.tickets[] | "- \(.[0]): \(.[1])"' <<<"$row")
  for sm in $SUMMARISERS; do
    out="results/$id-$sm.json"
    [[ -s "$out" ]] && { echo "skip $id/$sm"; continue; }
    echo "== $id / $sm"
    if [[ ! -s "$dir/digest-$sm.md" ]]; then   # digests are cached; delete one to regenerate
      if [[ "$sm" == "claude-team" ]]; then
        "$CLAUDE" -p "$(cat team-prompt.md)" < "$dir/transcript.txt" > "$dir/digest-$sm.md" 2>/dev/null
      else
        PIROBA_CONFIG=/dev/null PIROBA_SUMMARISER=$sm PIROBA_LLM="${PIROBA_LLM:-gemma4:12b}" \
          ../piroba.sh summarise "$dir" >/dev/null 2>&1
        cp "$dir/digest.md" "$dir/digest-$sm.md"
      fi
    fi
    prompt="${JUDGE_PROMPT/\{\{EXPECTED\}\}/$expected}"
    prompt="${prompt/\{\{DIGEST\}\}/$(cat "$dir/digest-$sm.md")}"
    # </dev/null: claude must not eat the case list on stdin
    "$CLAUDE" -p "$prompt" --output-format text </dev/null 2>>"$out.err" \
      | python3 -c 'import sys,re,json; m=re.search(r"\{.*\}", sys.stdin.read(), re.S); print(json.dumps(json.loads(m.group(0)), indent=1) if m else "")' > "$out"
    jq -e . "$out" >/dev/null 2>&1 || { echo "  judge output not JSON, see $out"; }
  done
done
python3 report.py
