# MeetsVault — Session Progress

## Status: Phases 1–3 complete, blocked on permissions before Phase 4

---

## What's been built

### Phase 1 ✅ — Scaffold
- Xcode project generated via `xcodegen` from `project.yml`
- Menu-bar-only app (`LSUIElement = YES`, no Dock icon, no window)
- `NSStatusItem` with waveform SF Symbol
- URL scheme `meetsvault://` registered with Launch Services
- `meetsvault://start`, `meetsvault://stop`, unknown commands all routed and logged

### Phase 2 ✅ — Recording pipeline
- `MicrophoneCapture`: `AVAudioEngine` tap → 16 kHz mono PCM16 WAV
- `SystemAudioCapture`: `ScreenCaptureKit` `SCStream` → 16 kHz mono PCM16 WAV
- `AudioMixer`: post-recording float mix of mic + system → `combined.wav`
- `AudioRecorder`: orchestrator with `idle / recording / transcribing` state machine and delegate
- `PermissionsChecker`: mic + screen recording status and request helpers

### Phase 3 ✅ — URL scheme wired
- `meetsvault://start?title=...` → `AudioRecorder.start(title:)`
- `meetsvault://stop` → `AudioRecorder.stop()`
- Edge cases handled: already-recording, not-recording — user notification shown
- Menu bar icon changes state (waveform → red dot → spinner) and shows live timer

---

## Blocked: permissions not yet granted

The first `meetsvault://start` correctly triggered the Screen Recording permission request but the test showed it was denied. Before Phase 4, the user must:

1. **System Settings → Privacy & Security → Screen Recording** → enable MeetsVault
2. **System Settings → Privacy & Security → Microphone** → enable MeetsVault
3. Restart the app, then verify with:

```bash
pkill -x MeetsVault 2>/dev/null
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "MeetsVault.app" -path "*/Debug/*" 2>/dev/null | head -1)
"$BUILT_APP/Contents/MacOS/MeetsVault" &> /tmp/meetsvault_verify.log &
sleep 3
open 'meetsvault://start?title=PermissionsTest'
sleep 8
open 'meetsvault://stop'
sleep 5
cat /tmp/meetsvault_verify.log
find ~/Library/Application\ Support/MeetsVault/recordings/ -name "*.wav" -exec ls -lh {} \;
```

Expected: `mic.wav`, `system.wav`, `combined.wav` in the recordings folder, all > 0 bytes.

---

## Next: Phase 4 — Transcription

Once permissions are confirmed:

1. Add **WhisperKit** via SPM: `https://github.com/argmaxinc/WhisperKit`
2. Create `TranscriptionEngine` protocol + `WhisperKitEngine` implementation
3. Create `ModelManager` (download/cache models in `~/Library/Application Support/MeetsVault/models/`)
4. Create `Settings.swift` (UserDefaults wrapper)
5. Build `WelcomeWindow` (SwiftUI, 5-step first-launch flow: welcome → pick model → permissions → download → done)
6. Wire `AudioRecorder.stop()` to transcribe `combined.wav` after mixing

Transcription is **post-recording batch** (not live). Whisper model is downloaded once on first launch and cached. Default model: `small` (466 MB). Engine is behind a `TranscriptionEngine` protocol for future Intel/whisper.cpp support.

---

## Key file locations

| Path | Purpose |
|---|---|
| `project.yml` | xcodegen spec — run `xcodegen generate` after adding new source files |
| `MeetsVault/MeetsVault/` | All Swift sources |
| `MeetsVault/MeetsVault/Recording/` | Mic, system audio, mixer, recorder |
| `MeetsVault/MeetsVault/MenuBar/` | Status item, icon states, menu |
| `MeetsVault/MeetsVault/URLScheme/` | URL routing |
| `PLAN.md` | Full implementation plan with all decisions and remaining phases |

## Build command

```bash
xcodegen generate --spec project.yml
xcodebuild -project MeetsVault.xcodeproj -scheme MeetsVault -configuration Debug \
  -destination "platform=macOS,arch=arm64" build
```

## Git log
- `c92a568` phase 2+3: audio recording pipeline + URL scheme wiring
- `c3330c6` phase 1: menu-bar scaffold + URL scheme registered
