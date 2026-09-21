#!/bin/bash
# piroba — records your side of any call, transcribes it locally,
# and drafts the actions you committed to. Nothing leaves this machine except
# the transcript you hand to your own Claude Code session.
#
#   piroba.sh process DIR   transcribe + draft actions for one recording
#   piroba.sh summarise DIR re-run only the digest step (e.g. after changing model)
#   piroba.sh review [ID]   open a digest (latest by default) in Claude Code to file it
# Recording itself is done by Piroba.app (src/), which calls `process`.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MEETINGS="$HERE/meetings"
[[ -f "$HERE/config.env" ]] && source "$HERE/config.env"   # written by the app's Settings
MODEL="${PIROBA_MODEL:-mlx-community/whisper-large-v3-turbo}"
SUMMARISER="${PIROBA_SUMMARISER:-ollama}"   # ollama (local) | claude | none
LLM="${PIROBA_LLM:-gemma4:12b}"
CLAUDE="${PIROBA_CLAUDE:-$HOME/.local/bin/claude}"
MIN_SECONDS="${PIROBA_MIN_SECONDS:-60}"   # shorter than this is a mic test

log() { echo "$(date '+%F %T') $*"; }
notify() { osascript -e "display notification \"$2\" with title \"$1\"" 2>/dev/null; }


# --- process -----------------------------------------------------------------
process_dir() {
  local dir secs
  dir=$(cd "$1" 2>/dev/null && pwd) || { log "no such dir: $1"; return 1; }
  ls "$dir"/audio-*.wav >/dev/null 2>&1 || { log "no audio in $dir"; return 1; }

  # segments are 16k mono already; re-encode anyway so a stray odd segment can't break the concat
  for f in "$dir"/audio-*.wav; do echo "file '$f'"; done > "$dir/segments.txt"
  ffmpeg -nostdin -f concat -safe 0 -i "$dir/segments.txt" -ac 1 -ar 16000 -c:a pcm_s16le \
         -y "$dir/audio.wav" >>"$dir/ffmpeg.log" 2>&1 \
    && rm -f "$dir"/audio-*.wav "$dir/segments.txt"
  secs=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$dir/audio.wav" 2>/dev/null | cut -d. -f1)
  secs=${secs:-0}
  if (( secs < MIN_SECONDS )); then
    log "$dir is ${secs}s, too short — binning"
    rm -rf "$dir"; return 0
  fi

  log "transcribing $dir (${secs}s)"
  mlx_whisper "$dir/audio.wav" --model "$MODEL" --language en \
      --output-dir "$dir" --output-name transcript --output-format txt >>"$dir/whisper.log" 2>&1
  [[ -s "$dir/transcript.txt" ]] || { log "transcription failed, see $dir/whisper.log"; return 1; }

  summarise "$dir"
}

summarise() {
  local dir; dir=$(cd "$1" && pwd)
  [[ -s "$dir/transcript.txt" ]] || { log "no transcript in $dir"; return 1; }
  if [[ "$SUMMARISER" == "none" ]]; then
    log "transcript only (summary off)"; notify "Meeting captured" "$(basename "$dir") — transcript ready"; return 0
  fi
  log "drafting actions with $SUMMARISER"
  PROMPT_TEXT=$(cat <<'PROMPT'
This is a transcript of ONE side of a meeting — only my microphone was recorded,
so you are reading my half of the conversation. The other side is missing;
infer it only where it is obvious, and never invent what someone else said.

Write a markdown digest with exactly these sections:

## What this was about
Two or three sentences. Plain language, no meeting-minutes throat-clearing.

## Actions I committed to
Only things *I* said I would do. One line each, imperative, with who it is for
if that is clear. If I committed to nothing, say so — do not pad the list.

## Proposed ADO items
For each action that looks like real xTrade work, propose one work item:
title, type (Bug/Product Backlog Item/Task), and a one-line description.
Never mention the meeting, the call, the transcript, or who raised it in any
proposed ticket text. Mark each `- [ ]` so I can tick the ones to file.
If nothing warrants a ticket, write "None".

## Open questions
Things I said I needed to check or ask someone. Skip the section if empty.

Nothing is filed here. This is a draft for me to approve.
PROMPT
)
  if [[ "$SUMMARISER" == "claude" ]]; then
    "$CLAUDE" -p "$PROMPT_TEXT" < "$dir/transcript.txt" > "$dir/digest.md" 2>"$dir/summary.log"
  else
    # HTTP API, not `ollama run`: no TTY control codes, and think=false skips minutes of reasoning spew
    jq -n --arg m "$LLM" --arg p "$PROMPT_TEXT" --rawfile t "$dir/transcript.txt" \
       '{model:$m, stream:false, think:false, options:{temperature:0.2},
         prompt:($p + "\n\n--- TRANSCRIPT (my side only) ---\n" + $t)}' \
      | curl -s --max-time 600 http://localhost:11434/api/generate -d @- 2>"$dir/summary.log" \
      | jq -r '.response // empty' > "$dir/digest.md"
  fi

  if [[ -s "$dir/digest.md" ]]; then
    log "digest ready: $dir/digest.md"
    notify "Meeting captured" "$(basename "$dir") — actions drafted"
    [[ -t 1 ]] && open "piroba://actions/$(basename "$dir")" 2>/dev/null   # from a terminal: show the panel
  else
    log "$SUMMARISER produced nothing, see $dir/summary.log"
  fi
}

# --- review ------------------------------------------------------------------
review() {
  local dir="${1:-$(ls "$MEETINGS" 2>/dev/null | tail -1)}"
  [[ -n "$dir" && -f "$MEETINGS/$dir/digest.md" ]] || { echo "no digest for '${dir:-latest}'"; exit 1; }
  cd "$MEETINGS/$dir" && exec "$CLAUDE" "Read digest.md. Show me the proposed ADO items, and file only the ones I confirm."
}

case "${1:-}" in
  process)   process_dir "$2" ;;
  summarise) summarise "$2" ;;
  review)  review "${2:-}" ;;
  *)       sed -n '2,8p' "$0"; exit 1 ;;
esac
