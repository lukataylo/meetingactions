# Piroba

Georgian for "promise". A macOS menu-bar app that records your side of any call,
transcribes it on the Mac, drafts the actions you committed to, and hands each one
to your own Claude Code session. Nothing leaves the machine unless you pick
Claude Code as the summariser.

## How it works

- Any app opening the microphone counts as a call (CoreAudio process list, so
  Teams, Zoom, Meet, FaceTime all work). A floating pill shows a waveform and timer.
- Mic free for 60 s = call over. Audio is written in segments so a device change
  mid-call (Teams mute/unmute) doesn't lose the rest.
- `piroba.sh process` concatenates, runs `mlx_whisper`, then asks Ollama for a digest:
  what it was about, actions you committed to, proposed ADO items, open questions.
- A Things-style panel lists the actions. Tick them off, or hover and hit the arrow
  to paste one into a single interactive `claude` session in your workspace.

## Requirements

macOS 14.4+, Apple Silicon. `brew install ffmpeg jq`, `pip install mlx-whisper`,
[Ollama](https://ollama.com) with a model pulled (default `gemma4:12b`), and
optionally the `claude` CLI at `~/.local/bin/claude`.

## Install

```
git clone https://github.com/lukataylo/meetingactions.git ~/piroba
cd ~/piroba && ./build.sh
cp com.luka.piroba.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.luka.piroba.plist
```

The plist assumes `~/piroba` and the user `lukadadiani`; edit the paths if yours differ.
Keep the folder out of `~/Documents` — launchd agents can't read it without a TCC grant.
Settings live in the menu-bar popover and are mirrored to `config.env` for the script.

## Files

```
src/App.swift       menu bar, auto-record loop, meeting list, Claude handoff
src/Recorder.swift  AVAudioEngine tap -> wav segments + levels for the waveform
src/Pill.swift      the floating recording capsule
src/Actions.swift   the post-meeting actions panel
src/Settings.swift  settings model + view; writes config.env
src/Audio.swift     mic-in-use detection, input device list
piroba.sh           process | summarise | review
icon.py             renders Piroba.icns
```
