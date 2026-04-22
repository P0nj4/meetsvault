# MeetsVault

A native macOS menu-bar app that records meetings and transcribes them locally using [WhisperKit](https://github.com/argmaxinc/WhisperKit). No cloud, no subscription, fully private.

![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue) ![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-required-lightgrey) ![License](https://img.shields.io/badge/license-MIT%20%2B%20Commons%20Clause-green)

---

## Features

- Records system audio + microphone simultaneously
- Transcribes locally using Apple Neural Engine (WhisperKit)
- Saves transcripts as Markdown files with timestamps
- Menu-bar only — no Dock icon, no window clutter
- Triggered via menu bar or URL scheme (`meetsvault://start`, `meetsvault://stop`)
- Multiple Whisper model sizes (tiny → large-v3)
- Language switcher (20+ languages)
- Audio files auto-deleted after 7 days; transcripts kept forever
- Re-transcribe any old recording with a different model

---

## Requirements

- macOS 15 Sequoia or later
- Apple Silicon (M1 or later)
- Xcode 16+ (to build from source)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

---

## Getting Started

### Build from source

```bash
git clone git@github.com:P0nj4/meetsvault.git
cd meetsvault
xcodegen generate --spec project.yml
xcodebuild -project MeetsVault.xcodeproj \
  -scheme MeetsVault \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath build \
  build
```

The app will be at `build/Build/Products/Release/MeetsVault.app`.

Drag it to `/Applications`. On first launch, right-click → **Open** to bypass Gatekeeper (the app is unsigned).

### First launch

The onboarding walks you through:

1. Choosing a Whisper model (default: `small` — good balance of speed and accuracy)
2. Choosing where to save transcripts and audio (default: `~/Meetings`)
3. Granting Microphone and Screen Recording permissions
4. Downloading the selected model (~466 MB for `small`)

After setup, MeetsVault lives in your menu bar as a waveform icon.

---

## Usage

### Menu bar

Click the waveform icon → **Start Recording** to begin. The icon turns red while recording. Click **Stop Recording** when done — transcription starts automatically.

### URL scheme

MeetsVault registers the `meetsvault://` scheme, so you can trigger it from scripts, shortcuts, or other apps:

```bash
# Start a named recording
open 'meetsvault://start?title=Weekly%20Sync'

# Stop and transcribe
open 'meetsvault://stop'
```

### Output

Transcripts are saved to your chosen folder (default `~/Meetings`) as:

```
2026-04-22_1430_weekly-sync.md
2026-04-22_1430_weekly-sync.wav   ← auto-deleted after 7 days
```

Each `.md` includes frontmatter (date, duration, model, language) and timestamped transcript segments:

```markdown
---
title: Weekly Sync
date: 2026-04-22
started_at: 14:30:05
ended_at: 15:12:48
duration: 00:42:43
language: en
model: whisperkit-small
audio_source: system+microphone
audio_file: 2026-04-22_1430_weekly-sync.wav
---

# Weekly Sync

## Transcript

[00:00:00] Alright, let's get started.
[00:00:08] Thanks everyone for joining.
```

---

## Model sizes

| Model | Size | Notes |
|---|---|---|
| tiny | 75 MB | Fastest, least accurate |
| base | 142 MB | |
| small | 466 MB | **Default** — good for most use cases |
| medium | 1.5 GB | More accurate, slower |
| large-v3 | 3 GB | Most accurate |

Models are downloaded once and cached in `~/Library/Application Support/MeetsVault/models/`.

---

## Privacy

- All processing happens on-device
- No data is sent to any server
- Audio is stored temporarily in `~/Library/Application Support/MeetsVault/recordings/` during transcription, then moved to your output folder (`.wav`) or deleted (temp files)
- `.wav` files in your output folder are automatically deleted after 7 days

---

## License

[MIT + Commons Clause](LICENSE) — free to use and modify (including commercially), but you may not sell it or offer it as a paid product or service.
