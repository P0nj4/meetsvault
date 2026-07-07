# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Keeping user-facing docs in sync

Whenever a change alters something the user sees or does — menu items, dialogs, onboarding steps, permissions, URL scheme behavior, file naming, transcript frontmatter, audio source modes, output folders, etc. — update **all three** of these files in the same commit:

- `README.md` (Features list, Usage section, any relevant snippet)
- `docs/USER_MANUAL.md` (English)
- `docs/USER_MANUAL.es.md` (Spanish — mirror of the English version)

If a change is purely internal (refactor, dependency bump, log message, threshold tweak with no UX impact), skip the docs. When in doubt, ask. Out-of-date manuals are worse than no manuals.

---

## Project

MeetsVault is a native macOS menu-bar app (macOS 15+, Apple Silicon) that records meetings and transcribes them locally using WhisperKit. No cloud, no network calls during recording or transcription.

## Build

Requires: Xcode 16+, `xcodegen` (`brew install xcodegen`).

**Adding a new Swift file:** sources are picked up by glob from the `MeetsVault/` directory, but `project.pbxproj` must be regenerated for Xcode to see them. Run `xcodegen generate --spec project.yml` after creating any new `.swift` file.

```bash
# Regenerate .xcodeproj after editing project.yml OR adding new source files
xcodegen generate --spec project.yml

# Build release binary
xcodebuild -project MeetsVault.xcodeproj \
  -scheme MeetsVault \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath build \
  build
```

Output: `build/Build/Products/Release/MeetsVault.app`

A `postBuildScripts` phase in `project.yml` stamps `CFBundleVersion` with `date +%Y%m%d%H%M` and re-signs the bundle. It runs after `ProcessInfoPlistFile` (declared via `inputFiles`).

## Tests

Unit tests live in `MeetsVaultTests/` (`FilenameBuilder`, `TranscriptCleaner`, `LanguageCode`, `TranscriptWriter`).

```bash
xcodebuild test \
  -project MeetsVault.xcodeproj \
  -scheme MeetsVault \
  -destination "platform=macOS,arch=arm64"
```

## Architecture

The app is entirely AppKit-based (no SwiftUI windows). `MeetsVaultApp` is the `@main` entry point but only hosts `AppDelegate` via `@NSApplicationDelegateAdaptor`. All UI is driven from `AppDelegate`.

**Data flow for a recording session:**

1. `MenuBarController` (via menu-bar click or URL scheme) calls `presentCaptureSourcePrompt(title:)`, which opens `CaptureSourceWindow`. The user picks `CaptureMode.micOnly` (laptop speakers — avoids echo when not using headphones) or `CaptureMode.micAndSystem` (headphones — current full capture).
2. On confirmation, `AudioRecorder.start(title:captureMode:)` is invoked. Screen Recording permission is only required for `.micAndSystem`.
3. `AudioRecorder` runs `MicrophoneCapture` always, and `SystemAudioCapture` only in `.micAndSystem`, writing `mic.wav` (and optionally `system.wav`) to a UUID session folder in `~/Library/Application Support/MeetsVault/recordings/<uuid>/`.
4. On stop, the path bifurcates by mode:
   - **`.micOnly`**: transcribe `mic.wav` only; no mixing, no dedup; `mic.wav` is moved as the output audio; frontmatter `audio_source: microphone`.
   - **`.micAndSystem`**: `AudioMixer.mix(mic:system:output:)` produces `combined.wav`; both streams are transcribed separately, aligned by `firstSampleTime` offsets, and merged via `TranscriptDeduplicator` to remove echo overlap; frontmatter `audio_source: system+microphone`.
5. `WhisperKitEngine.prepare(modelName:progress:)` loads the model (downloads if not cached to `~/Library/Application Support/MeetsVault/models/`).
6. `WhisperKitEngine.transcribe(audioURL:language:speaker:)` returns `[TranscriptSegment]`.
7. `TranscriptWriter.write(...)` saves the `.md` and moves the audio file to the output folder (`Settings.shared.meetingsDirectory`, default `~/Meetings`).
8. Session temp folder is deleted; `AudioRetentionJob` deletes `.wav` files older than 7 days from the output folder.

**Key types:**
- `AudioRecorder` — owns the recording state machine (`idle → recording → transcribing → idle`); notifies `AudioRecorderDelegate`
- `MenuBarController` — implements `AudioRecorderDelegate`; rebuilds the `NSMenu` on every state change
- `Settings` — thin `UserDefaults` wrapper (singleton); all persistent config lives here
- `TranscriptionEngine` — protocol; `WhisperKitEngine` is the only implementation
- `ModelManager` — tracks available/downloaded Whisper model variants

**URL scheme:** `meetsvault://start?title=...` and `meetsvault://stop` are handled by `URLSchemeHandler`. `start` opens the `CaptureSourceWindow` prompt (it does NOT begin recording directly — the user must choose mic-only vs mic+system every time). `stop` calls `AudioRecorder.stop()` directly.

**Transcript formatting knobs** (`TranscriptCleaner.swift`): segments from WhisperKit are grouped into paragraphs by `merge(...)`. Tunable thresholds:
- `pauseThreshold` (default `0.5s`) — a gap larger than this between consecutive segments starts a new paragraph.
- `maxParagraphChars` (default `500`) — once a paragraph exceeds this and ends with `.!?`, force a split.
- Changing these directly affects transcript readability — they're the first knobs to tweak when output feels too dense or too fragmented.

**Settings keys** (written to `com.germanpereyra.meetsvault` domain via `UserDefaults.standard`):
- `selectedModelName` — Whisper variant name (e.g. `"small"`)
- `transcriptionLanguage` — BCP-47 code (e.g. `"en"`)
- `meetingsDirectoryPath` — absolute path string; defaults to `~/Meetings`
- `hasCompletedOnboarding` — bool
- `hasAcceptedTerms` — bool; gated on step 1 of `WelcomeWindow` before onboarding can proceed
- `lastCaptureMode` — raw value of the last `CaptureMode` the user picked; `nil` until the first successful Start

Note: capture mode is persisted in Settings as `lastCaptureMode` and pre-selects the dialog the next time it opens. On first-ever launch it's `nil` — nothing is pre-selected and the button stays disabled until the user picks.

**Transcript format:** Markdown with YAML frontmatter (title, date, started_at, ended_at, duration, language, model, audio_source, audio_file) followed by timestamped `[HH:MM:SS]` segments.
