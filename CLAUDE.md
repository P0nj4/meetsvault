# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

MeetsVault is a native macOS menu-bar app (macOS 15+, Apple Silicon) that records meetings and transcribes them locally using WhisperKit. No cloud, no network calls during recording or transcription.

## Build

Requires: Xcode 16+, `xcodegen` (`brew install xcodegen`).

```bash
# Regenerate .xcodeproj after editing project.yml
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

1. `MenuBarController` (or `URLSchemeHandler`) calls `AudioRecorder.start(title:)`
2. `AudioRecorder` runs `MicrophoneCapture` and `SystemAudioCapture` in parallel, writing `mic.wav` and `system.wav` to a UUID session folder in `~/Library/Application Support/MeetsVault/recordings/<uuid>/`
3. On stop: `AudioMixer.mix(mic:system:output:)` combines them into `combined.wav`
4. `WhisperKitEngine.prepare(modelName:progress:)` loads the model (downloads if not cached to `~/Library/Application Support/MeetsVault/models/`)
5. `WhisperKitEngine.transcribe(audioURL:language:)` returns `[TranscriptSegment]`
6. `TranscriptWriter.write(...)` saves the `.md` and moves `combined.wav` to the output folder (`Settings.shared.meetingsDirectory`, default `~/Meetings`)
7. Session temp folder is deleted; `AudioRetentionJob` deletes `.wav` files older than 7 days from the output folder

**Key types:**
- `AudioRecorder` — owns the recording state machine (`idle → recording → transcribing → idle`); notifies `AudioRecorderDelegate`
- `MenuBarController` — implements `AudioRecorderDelegate`; rebuilds the `NSMenu` on every state change
- `Settings` — thin `UserDefaults` wrapper (singleton); all persistent config lives here
- `TranscriptionEngine` — protocol; `WhisperKitEngine` is the only implementation
- `ModelManager` — tracks available/downloaded Whisper model variants

**URL scheme:** `meetsvault://start?title=...` and `meetsvault://stop` are handled by `URLSchemeHandler`, which calls into the shared `AudioRecorder` via `AppDelegate`.

**Settings keys** (written to `com.germanpereyra.meetsvault` domain via `UserDefaults.standard`):
- `selectedModelName` — Whisper variant name (e.g. `"small"`)
- `transcriptionLanguage` — BCP-47 code (e.g. `"en"`)
- `meetingsDirectoryPath` — absolute path string; defaults to `~/Meetings`
- `hasCompletedOnboarding` — bool
- `hasAcceptedTerms` — bool; gated on step 1 of `WelcomeWindow` before onboarding can proceed

**Transcript format:** Markdown with YAML frontmatter (title, date, started_at, ended_at, duration, language, model, audio_source, audio_file) followed by timestamped `[HH:MM:SS]` segments.
