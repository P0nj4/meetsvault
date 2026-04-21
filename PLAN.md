# MeetsVault — Implementation Plan

> This is a **handoff document for Sonnet**. All product decisions are locked. Execute phases 1→6 in order. After each phase, stop and run the verification checklist before starting the next.

---

## 1. Product summary

**MeetsVault** is a native macOS menu-bar-only app that records meetings (system audio + microphone), transcribes them locally with WhisperKit, and saves a markdown transcript to `~/Meetings/`. No cloud, no cost, fully offline after the initial model download.

### Locked decisions (do not re-open)

| Topic | Decision |
|---|---|
| App name | **MeetsVault** |
| Bundle ID | `com.germanpereyra.meetsvault` |
| URL scheme | `meetsvault://start[?title=<urlencoded>]` and `meetsvault://stop` |
| Target OS | macOS **15 Sequoia** minimum (deployment target: `15.0`) |
| Architecture | **Apple Silicon only** for v1 (Intel later via protocol) |
| UI model | **Menu-bar only** — `LSUIElement = YES`, no Dock icon, no main window except the first-launch welcome |
| Audio sources | System audio (`ScreenCaptureKit`) **+** microphone (`AVAudioEngine`), mixed |
| Audio format on disk | 16 kHz mono WAV (PCM, signed 16-bit) — required by Whisper |
| Transcription mode | **Post-recording (batch)**, not live |
| Transcription engine | **WhisperKit** (Swift Package, uses Apple Neural Engine) |
| Engine abstraction | `TranscriptionEngine` protocol so a `WhisperCppEngine` can be added later without touching callers |
| Model choices | `tiny`, `base`, `small` *(default)*, `medium`, `large-v3` |
| Model cache dir | `~/Library/Application Support/MeetsVault/models/` |
| Output dir | `~/Meetings/` (use `FileManager.default.homeDirectoryForCurrentUser`, never hardcode a username) |
| Output file | `YYYY-MM-DD_HHMM_<slug>.md` + sibling `.wav` |
| Audio retention | Keep `.wav` files 7 days, then auto-delete on app launch |
| Diarization | **None** in v1 |
| Stop behavior | Silent save + macOS notification "Transcript ready" with Open action |
| Default language | English; switchable from the menu bar |
| App Sandbox | **Off** for v1 (simpler `~/Meetings` + model cache access) |
| Signing | Unsigned local dev build; user does right-click → Open on first launch |

### Explicitly out of scope for v1
- Live/streaming transcription
- Speaker diarization
- Intel Mac support (but code must be structured to allow it later)
- App Store distribution, notarization
- Cloud transcription fallback
- Auto meeting detection (Zoom/Meet/Teams)
- Summary / action-items generation
- Global hotkeys

---

## 2. Prerequisites

Before starting:
- Xcode 16+ installed (user is downloading during planning)
- macOS Sequoia 15+
- Apple Silicon Mac
- Command-line tools: `xcode-select --install` if not already present

No Apple Developer account needed.

---

## 3. Project layout

Create the Xcode project at `/Users/german/development/meetings_transcription/MeetsVault/`.

```
meetings_transcription/
├── PLAN.md                              (this file)
├── MeetsVault.xcodeproj/
└── MeetsVault/
    ├── MeetsVaultApp.swift              SwiftUI @main, AppDelegate adaptor, URL handling
    ├── AppDelegate.swift                Lifecycle, permissions check, startup retention job
    ├── Info.plist                       LSUIElement, URL scheme, permission strings
    ├── MeetsVault.entitlements          Audio input, screen capture
    │
    ├── MenuBar/
    │   ├── MenuBarController.swift      NSStatusItem, menu construction, icon state
    │   └── MenuBarIconState.swift       enum { idle, recording, transcribing } + SF Symbol mapping
    │
    ├── Recording/
    │   ├── AudioRecorder.swift          Orchestrator: start/stop, filename, mixing
    │   ├── SystemAudioCapture.swift     ScreenCaptureKit SCStream for system audio
    │   ├── MicrophoneCapture.swift      AVAudioEngine input tap
    │   └── AudioMixer.swift             Post-recording offline mix of mic.wav + system.wav → combined.wav
    │
    ├── Transcription/
    │   ├── TranscriptionEngine.swift    protocol
    │   ├── WhisperKitEngine.swift       WhisperKit implementation
    │   ├── ModelManager.swift           Download / list / switch models; progress reporting
    │   └── TranscriptSegment.swift      struct { startSeconds, endSeconds, text }
    │
    ├── Output/
    │   ├── TranscriptWriter.swift       Markdown formatter + file writer
    │   ├── FilenameBuilder.swift        Date-stamped, slug-sanitized filenames
    │   └── AudioRetentionJob.swift      Delete .wav older than 7 days
    │
    ├── URLScheme/
    │   └── URLSchemeHandler.swift       Parse meetsvault:// URLs, route to recorder
    │
    ├── Settings/
    │   ├── Settings.swift               UserDefaults wrapper: selected model, language, etc.
    │   └── LanguageCode.swift           Supported whisper language codes + display names
    │
    ├── Notifications/
    │   └── NotificationManager.swift    UNUserNotificationCenter, "Transcript ready" with Open action
    │
    ├── Permissions/
    │   └── PermissionsChecker.swift     Microphone + Screen Recording status
    │
    └── UI/
        ├── WelcomeWindow.swift          SwiftUI first-launch model picker + permissions explainer
        ├── ModelDownloadView.swift      Progress UI for model download
        └── LanguagePickerMenu.swift     Builds NSMenu submenu of languages
```

---

## 4. Info.plist keys (exact values)

```xml
<key>LSUIElement</key>
<true/>

<key>LSMinimumSystemVersion</key>
<string>15.0</string>

<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.germanpereyra.meetsvault.url</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>meetsvault</string>
    </array>
  </dict>
</array>

<key>NSMicrophoneUsageDescription</key>
<string>MeetsVault records your microphone so your voice is included in meeting transcripts.</string>

<key>NSScreenCaptureUsageDescription</key>
<string>MeetsVault captures system audio (required to transcribe what other meeting participants say). Your screen is not recorded.</string>
```

### Entitlements (`MeetsVault.entitlements`)
```xml
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.app-sandbox</key>
<false/>
```

---

## 5. Dependencies

Add via **Swift Package Manager** in Xcode:

- **WhisperKit** — `https://github.com/argmaxinc/WhisperKit` — pin to latest stable (`1.0.0+`)
  - Product: `WhisperKit`

No other third-party dependencies. Everything else is Apple-framework:
- `ScreenCaptureKit`
- `AVFoundation`
- `AppKit`
- `SwiftUI` (just for the Welcome window)
- `UserNotifications`
- `UniformTypeIdentifiers`

---

## 6. Core interfaces

### `TranscriptionEngine` protocol

```swift
protocol TranscriptionEngine {
    /// One-time setup; downloads model if needed. Reports progress 0.0...1.0.
    func prepare(modelName: String, progress: @escaping (Double) -> Void) async throws

    /// Transcribe the given .wav file. Returns ordered segments.
    func transcribe(
        audioURL: URL,
        language: String?
    ) async throws -> [TranscriptSegment]
}

struct TranscriptSegment {
    let startSeconds: Double
    let endSeconds: Double
    let text: String
}
```

`WhisperKitEngine` wraps `WhisperKit` and maps its segment output to `TranscriptSegment`.

### `AudioRecorder` public surface

```swift
enum RecordingState { case idle, recording, transcribing }

protocol AudioRecorderDelegate: AnyObject {
    func recorder(_: AudioRecorder, didChangeState: RecordingState)
    func recorder(_: AudioRecorder, didFinishTranscript url: URL, title: String)
    func recorder(_: AudioRecorder, didFail error: Error)
}

final class AudioRecorder {
    weak var delegate: AudioRecorderDelegate?
    var state: RecordingState { get }

    func start(title: String?) async throws       // no-op if already recording
    func stop() async                              // no-op if not recording
}
```

### URL routing

`URLSchemeHandler.handle(_ url: URL)`:
- `meetsvault://start` → `recorder.start(title: url.queryItem("title"))`
- `meetsvault://stop`  → `recorder.stop()`
- Unknown host/path → log + notification "Unknown MeetsVault command"

---

## 7. Audio pipeline detail

### Capture (two independent writers during the meeting)

**Microphone** — `MicrophoneCapture`:
- `AVAudioEngine` with input node tap
- Convert to 16 kHz mono PCM16 via `AVAudioConverter`
- Write to `mic.wav` via `AVAudioFile`

**System audio** — `SystemAudioCapture`:
- `SCShareableContent.current` → pick the main display (content filter matches all displays/apps)
- `SCStreamConfiguration`:
  - `capturesAudio = true`
  - `excludesCurrentProcessAudio = true` (don't capture our own output)
  - `sampleRate = 48000`, `channelCount = 2`
- `SCStream` with an `SCStreamOutput` of type `.audio`
- In the audio sample handler, convert each `CMSampleBuffer` to 16 kHz mono PCM16 and append to `system.wav`

Both start together when `AudioRecorder.start()` is called. Both stop when `.stop()` is called.

### Mix (post-recording)

**`AudioMixer.mix(mic: URL, system: URL) -> URL` (combined.wav)**:
- Use `AVAudioEngine` in offline manual-rendering mode
- Two `AVAudioPlayerNode`s scheduled simultaneously, both feeding the main mixer at equal gain (0.5 each)
- Render out to a new 16 kHz mono PCM16 `combined.wav`
- Length = max(mic duration, system duration)

### Files during a recording
```
~/Library/Application Support/MeetsVault/recordings/<uuid>/
  ├── mic.wav
  ├── system.wav
  └── combined.wav        (written during mix step)
```
After transcription succeeds, move `combined.wav` to `~/Meetings/<filename>.wav` and delete the uuid folder.

---

## 8. Filename and slug rules

`FilenameBuilder.build(title: String?, date: Date) -> String`:

1. Date prefix: `yyyy-MM-dd_HHmm` in the user's local timezone.
2. Slug:
   - If title is nil/empty → `untitled`
   - Else: lowercase, replace non-alphanumeric with `-`, collapse consecutive `-`, trim leading/trailing `-`, truncate to 60 chars
3. If the resulting `.md` path already exists, append `-2`, `-3`, …

Example: `2026-04-21_1430_weekly-sync.md`

---

## 9. Markdown output format

Written by `TranscriptWriter.write(...)` to `~/Meetings/<filename>.md`:

```markdown
---
title: Weekly Sync
date: 2026-04-21
started_at: 14:30:05
ended_at: 15:12:48
duration: 00:42:43
language: en
model: whisperkit-small
audio_source: system+microphone
audio_file: 2026-04-21_1430_weekly-sync.wav
---

# Weekly Sync

## Transcript

[00:00:00] Alright, let's get started with the weekly sync.
[00:00:08] Thanks everyone for joining.
[00:00:15] First on the agenda…

## Notes

<!-- your notes here -->
```

Timestamps use `HH:mm:ss` formatted from `TranscriptSegment.startSeconds`.

---

## 10. Menu bar UI spec

### Icon states (SF Symbols)
| State | Symbol | Tint |
|---|---|---|
| `idle` | `waveform` | template (system) |
| `recording` | `record.circle.fill` | `systemRed` |
| `transcribing` | `waveform.badge.magnifyingglass` | template + subtle animation (toggle every 500ms) |

### Menu structure
Build in `MenuBarController.rebuildMenu()` — called on state change.

```
[ when recording ]
● Recording · 00:03:42          (disabled info item, timer updates every 1s)
─────────────
Stop Recording                  ⌘⇧S   (nil-selector — uses action closure)

[ when idle ]
Start Recording                 ⌘⇧R

[ always ]
─────────────
Open Meetings Folder                  (opens ~/Meetings in Finder)
Recent Transcripts              ▸     (last 5 .md files in ~/Meetings, click → open)
─────────────
Language                        ▸     (current language marked ✓)
  English ✓
  Spanish
  French
  German
  Portuguese
  (…top 10 + "More Languages…")
Model: small                    ▸
  tiny (75 MB)
  base (142 MB)
  small (466 MB) ✓
  medium (1.5 GB)
  large-v3 (3 GB)
  ─────
  Download a different model…         (triggers download if not cached)
Re-transcribe audio…                  (NSOpenPanel filtered to .wav in ~/Meetings from last 7 days)
─────────────
About MeetsVault
Quit MeetsVault                 ⌘Q
```

Keyboard shortcuts are global via `NSMenuItem.keyEquivalentModifierMask`. No global hotkeys outside the app.

---

## 11. First-launch flow

On `applicationDidFinishLaunching`:
1. If `Settings.hasCompletedOnboarding == false`:
   - Show `WelcomeWindow` (SwiftUI, centered, ~520×420)
   - Steps:
     1. **Welcome** page — one-line description + Next
     2. **Pick a model** page — 5 radio buttons with name / size / speed hints; default `small` preselected
     3. **Permissions** page — explains Mic + Screen Recording requirements; "Request Permissions" button triggers first capture attempt which causes the system prompts
     4. **Downloading model** page — progress bar via `ModelManager.download()`; Next disabled until complete
     5. **Done** page — "MeetsVault lives in your menu bar. Click the icon to start recording." + Finish
   - On Finish: set `hasCompletedOnboarding = true`, close window.
2. Always:
   - Start `MenuBarController`
   - Run `AudioRetentionJob.run()` (delete `.wav` > 7 days in `~/Meetings/`)
   - Register URL scheme handler: `NSAppleEventManager.shared().setEventHandler(...)` for `kAEGetURL` / `kInternetEventClass`

---

## 12. Notifications

**`NotificationManager`** wraps `UNUserNotificationCenter`.

- Request authorization on first stop/transcribe, not at launch.
- Category: `TRANSCRIPT_READY` with an "Open" action.
- On transcript saved: post a notification
  - Title: `Transcript ready`
  - Body: `<title> · <duration>`
  - User info: `{ "filePath": <abs path> }`
- Delegate handles "Open" (and default tap): `NSWorkspace.shared.open(URL(fileURLWithPath: filePath))`.

Also post notifications for:
- "Already recording" (when `start` called mid-recording)
- "Nothing to stop" (when `stop` called while idle)
- "Transcription failed — <error>"

---

## 13. Settings (`UserDefaults` keys)

| Key | Type | Default |
|---|---|---|
| `hasCompletedOnboarding` | Bool | `false` |
| `selectedModelName` | String | `"small"` |
| `transcriptionLanguage` | String (ISO 639-1) | `"en"` |
| `downloadedModels` | [String] | `[]` |

---

## 14. Build phases

Each phase ends with a **verification step**. Do not advance until the step passes.

---

### Phase 1 — Scaffold ✅

**Goal**: An empty menu-bar app that launches, shows an icon, and logs incoming URL scheme hits.

**Tasks**:
1. Create Xcode project: *macOS App*, SwiftUI lifecycle, product name `MeetsVault`, org identifier `com.germanpereyra`, language Swift.
2. Set deployment target to 15.0.
3. Edit `Info.plist` — add `LSUIElement = YES`, URL scheme, permission strings (section 4). Remove any main window scene from `MeetsVaultApp.swift` — use `Settings {}` scene as a no-op placeholder, or use AppDelegate lifecycle.
4. Create `AppDelegate.swift` with `NSApplicationDelegateAdaptor`. In `applicationDidFinishLaunching`:
   - Register an Apple Event handler for `kInternetEventClass`/`kAEGetURL` → logs the received URL string.
   - Create `NSStatusItem` with a `waveform` SF Symbol (template).
   - Attach a simple `NSMenu` with one item "Quit MeetsVault".
5. Build and run.

**Verify**:
- App launches with **no** Dock icon and **no** window.
- The waveform icon appears in the top-right menu bar.
- Quit works.
- Open `meetsvault://ping` from Terminal (`open 'meetsvault://ping'`) — the Xcode console logs the URL.

---

### Phase 2 — Recording ✅

**Goal**: Click Start → captures mic + system audio to separate WAVs; Click Stop → mixes them into `combined.wav` in the recordings temp folder. No transcription yet.

**Tasks**:
1. Create `PermissionsChecker.swift` — functions to query mic (`AVCaptureDevice.authorizationStatus(for: .audio)`) and screen recording (`CGPreflightScreenCaptureAccess()`).
2. Create `MicrophoneCapture.swift`:
   - `AVAudioEngine` + input node tap at native format
   - `AVAudioConverter` to 16 kHz mono PCM16
   - `AVAudioFile` writer → `mic.wav`
   - `start(to url: URL)` / `stop()`
3. Create `SystemAudioCapture.swift`:
   - Fetch `SCShareableContent.current`; pick first display + empty exclusions
   - `SCStreamConfiguration` with `capturesAudio = true`, `excludesCurrentProcessAudio = true`, `sampleRate = 48000`, `channelCount = 2`
   - `SCContentFilter(display:excludingWindows:)` with no exclusions
   - `SCStream` with `SCStreamOutput` on `.audio` queue
   - Audio sample handler: `CMSampleBuffer` → `AVAudioPCMBuffer` → convert to 16 kHz mono PCM16 → append to `AVAudioFile`
   - `start(to url: URL)` / `stop()`
4. Create `AudioRecorder.swift`:
   - Orchestrates both captures
   - Makes `~/Library/Application Support/MeetsVault/recordings/<uuid>/` via `FileManager`
   - `start(title:)` → creates session dir, starts both captures, sets state = `.recording`
   - `stop()` → stops both, sets state = `.transcribing` (for now we'll just finalize and log the paths)
5. Create `AudioMixer.swift`:
   - Offline-render two `AVAudioPlayerNode`s into a new `combined.wav`
   - Equal gain (0.5) each
6. Wire Start/Stop into the menu bar menu (replace the single Quit item with full menu per section 10; Stop/Start toggles based on state).

**Verify**:
- First click of Start triggers mic + screen-recording permission prompts. Grant both.
- During recording, menu shows "● Recording · MM:SS" updating every second; icon turns red.
- Play audio from another app (YouTube, Spotify) and speak into the mic.
- Click Stop → after ~1s, session folder contains `mic.wav`, `system.wav`, `combined.wav`. Playing `combined.wav` should contain both your voice and the system audio at roughly equal levels.

---

### Phase 3 — URL scheme ✅

**Goal**: `meetsvault://start` and `meetsvault://stop` drive the recorder from an external caller.

**Tasks**:
1. Create `URLSchemeHandler.swift`:
   - `handle(_ url: URL, recorder: AudioRecorder)`
   - Route by `url.host` (`start` / `stop`)
   - Parse optional `title` query item (URL-decoded)
   - Call `recorder.start(title:)` / `recorder.stop()`
2. Replace the logging Apple-Event handler in `AppDelegate` with a real dispatch to `URLSchemeHandler.handle`.
3. Handle edge cases:
   - `start` while already recording → notification "Already recording" (use `NSUserNotification` temporarily or print — notifications are formalized in phase 5)
   - `stop` while idle → notification "Nothing to stop"

**Verify**:
- `open 'meetsvault://start?title=Weekly%20Sync'` → menu shows Recording state; session dir created.
- `open 'meetsvault://stop'` → Recording stops; combined.wav exists.
- `open 'meetsvault://start'` followed by `open 'meetsvault://start'` → second call is a no-op with a user-visible notice.
- `open 'meetsvault://stop'` while idle → no crash, user-visible notice.

---

### Phase 4 — Transcription ✅

**Goal**: After Stop, transcribe `combined.wav` with WhisperKit and print the segments to the console. Model selectable; first-launch welcome window.

**Tasks**:
1. Add WhisperKit via SPM (section 5).
2. Create `TranscriptionEngine.swift` protocol (section 6).
3. Create `TranscriptSegment.swift`.
4. Create `WhisperKitEngine.swift`:
   - `prepare(modelName:progress:)` → `WhisperKit(model: modelName, downloadBase: modelsDir, ...)` with progress callback
   - `transcribe(audioURL:language:)` → call `WhisperKit.transcribe(audioPath:)`, map `TranscriptionResult.segments` to `[TranscriptSegment]`
5. Create `ModelManager.swift`:
   - `modelsDir: URL` in Application Support
   - `isDownloaded(_ name: String) -> Bool`
   - `download(_ name: String, progress:) async throws` → delegates to `WhisperKitEngine.prepare`
   - Track downloaded models in `Settings.downloadedModels`
6. Create `Settings.swift` (UserDefaults wrapper).
7. Create `WelcomeWindow.swift` (SwiftUI) with the 5-step flow from section 11. Show on launch if `!hasCompletedOnboarding`. Use `NSApp.activate(ignoringOtherApps: true)` + `NSWindow` hosting a SwiftUI view.
8. Wire `AudioRecorder.stop()` so after mixing, it calls `engine.transcribe(...)` with the selected model and language, logs the segments.
9. Expose model switching in the menu: `Model ▸` submenu — click to switch `Settings.selectedModelName`; if not yet downloaded, show a progress HUD while it downloads (reuse `ModelDownloadView`).

**Verify**:
- Fresh install (delete UserDefaults via `defaults delete com.germanpereyra.meetsvault`): welcome window appears, walks through 5 steps, downloads `small` model (~466 MB) with visible progress.
- Record a 30-second meeting (talk + play a podcast clip). Click Stop. Console prints timestamped segments within ~1 minute on an M-series chip.
- Open Model submenu → switch to `base` → next recording transcribes with `base`.

---

### Phase 5 — Markdown output + notifications ✅

**Goal**: After transcription, a real `.md` file lands in `~/Meetings/` with full frontmatter, and a notification pops with an Open action.

**Tasks**:
1. Create `FilenameBuilder.swift` (section 8).
2. Create `TranscriptWriter.swift`:
   - `write(title: String?, startedAt: Date, endedAt: Date, language: String, model: String, segments: [TranscriptSegment], audioURL: URL) throws -> URL`
   - Formats per section 9
   - Moves `combined.wav` next to the `.md`
   - Returns the `.md` URL
3. Create `NotificationManager.swift`:
   - Request authorization on first use
   - Category `TRANSCRIPT_READY` with "Open" action
   - `postTranscriptReady(fileURL: URL, title: String, duration: TimeInterval)`
   - `UNUserNotificationCenterDelegate` handles Open → `NSWorkspace.shared.open(fileURL)`
4. Hook `AudioRecorder.stop()` → after transcription → call `TranscriptWriter` → call `NotificationManager.postTranscriptReady`.
5. Clean up: delete the `<uuid>` session dir after the transcript is saved. Keep only the `.wav` that was moved to `~/Meetings/`.
6. Wire menu items:
   - "Open Meetings Folder" → `NSWorkspace.shared.open(meetingsDir)`
   - "Recent Transcripts" submenu — scan `~/Meetings/*.md`, sort by mod date desc, take 5

**Verify**:
- Full flow: `meetsvault://start?title=Test Meeting` → talk for 20s → `meetsvault://stop` → notification within ~30s → click Open → markdown opens in default editor with frontmatter matching section 9, transcript segments with timestamps, sibling `.wav` file present.
- "Open Meetings Folder" opens Finder at `~/Meetings`.
- "Recent Transcripts" lists the new file.

---

### Phase 6 — Polish ✅

**Goal**: Everything in the menu spec works. App is ready for daily use.

**Tasks**:
1. **Language switcher**:
   - Create `LanguageCode.swift` with top languages (en, es, fr, de, pt, it, ja, zh, ko, ru, + `More…` open the full Whisper list)
   - Wire `Language ▸` menu to update `Settings.transcriptionLanguage`
   - Pass language into `engine.transcribe(language:)`
2. **Re-transcribe**:
   - Menu "Re-transcribe audio…" → `NSOpenPanel` starting at `~/Meetings/`, filter to `.wav`
   - On selection: run transcription + write a new `.md` next to the selected `.wav` (append `-retranscribed-<timestamp>` to the filename to not overwrite)
3. **Audio retention**:
   - Create `AudioRetentionJob.swift`
   - On `applicationDidFinishLaunching`, scan `~/Meetings/*.wav`, delete any with `contentModificationDate < Date().addingTimeInterval(-7*24*3600)`
   - Leave `.md` files alone (only audio ages out)
4. **Icon state polish**:
   - Transcribing state: 500ms Timer toggling between two SF Symbols for a subtle pulse
   - Proper tear-down on state changes
5. **About window**: small SwiftUI sheet with app name, version, a one-line description, and a link to the `~/Meetings` folder.
6. **Error surfaces**: all errors from recording/transcription post a notification with a clear message and log to `os_log(subsystem: "com.germanpereyra.meetsvault")`.

**Verify**:
- Switch language to Spanish, record a Spanish meeting → transcript is in Spanish with `language: es` in frontmatter.
- Re-transcribe a prior `.wav` with a different model → new `-retranscribed-...md` file appears.
- Change a `.wav`'s mod date to 8 days ago (`touch -t` trick), relaunch app → the `.wav` is deleted, its `.md` is not.
- Deny microphone permission in System Settings → Start Recording shows a clear "Microphone access denied — open System Settings" notification.
- Force-quit during a recording, relaunch → no crashes, session folder in Application Support can be cleaned up on next stop or next launch.

---

## 15. Known gotchas

- **`LSUIElement` without a main window**: if you leave the default SwiftUI `WindowGroup`, the app briefly flashes a window on launch. Replace with `Settings {}` scene or use pure AppDelegate lifecycle.
- **ScreenCaptureKit permission**: first `SCShareableContent.current` call triggers the Screen Recording prompt. User must grant, then **quit and relaunch** MeetsVault (macOS caches the denial). The welcome window should make this explicit.
- **`excludesCurrentProcessAudio = true`** is critical — without it, the app records its own notification sounds into the meeting.
- **`CMSampleBuffer` → `AVAudioPCMBuffer`**: use `CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer` and wrap into an `AVAudioPCMBuffer` with the source format, then `AVAudioConverter` to the 16 kHz mono target.
- **Mic + system audio timing drift**: both captures start at slightly different moments. For v1 we don't try to sync sample-accurate — just mix them. If drift becomes audible we can timestamp the first sample of each and pad with silence.
- **WhisperKit model download progress**: the download callback may fire from a background actor. Dispatch UI updates to `MainActor`.
- **URL scheme on first launch**: macOS registers schemes after the first launch of the built `.app` bundle. If URLs don't route, run the built `.app` once from Finder, not only from Xcode's Run.
- **Home directory**: always use `FileManager.default.homeDirectoryForCurrentUser`. Never hardcode a username — the target folder is `<home>/Meetings`.
- **Sandbox OFF but hardened runtime**: Xcode may still enable hardened runtime. That's fine; just make sure the entitlement file doesn't enable sandbox.
- **Apple Silicon only**: WhisperKit falls back to CPU on Intel but is dramatically slower. v1 doesn't gate on architecture — if someone runs on Intel they'll just have a slow experience. The engine protocol lets us swap in `WhisperCppEngine` later.

---

## 16. Acceptance criteria (end of phase 6)

All must pass for v1 to be considered complete:

- [ ] App installs by dragging `MeetsVault.app` to `/Applications`
- [ ] First launch shows welcome, picks model, downloads it, asks for permissions
- [ ] Subsequent launches go straight to menu bar (no window flash)
- [ ] No Dock icon
- [ ] `meetsvault://start?title=...` starts recording; `meetsvault://stop` ends it
- [ ] Menu bar icon reflects idle / recording / transcribing
- [ ] `.md` appears in `~/Meetings/` with correct frontmatter and timestamped transcript
- [ ] Sibling `.wav` is saved and auto-deleted after 7 days
- [ ] Language switcher works and is reflected in frontmatter
- [ ] Model switcher works; models download once and are cached
- [ ] Re-transcribe picks an old `.wav` and produces a new `.md`
- [ ] "Open Meetings Folder" and "Recent Transcripts" work
- [ ] Notification "Transcript ready" appears on finish and "Open" launches the `.md`
- [ ] No crashes across a 30-minute meeting
- [ ] Transcription of a 30-min clean English meeting with the `small` model completes in < 3 minutes on an M-series chip

---

## 17. Handoff notes for Sonnet

- Build **phase-by-phase**. Do not skip to phase 4 before phase 2 is verified end-to-end.
- Commit at the end of each passed phase. Suggested messages:
  `"phase 1: menu-bar scaffold + URL scheme registered"`, etc.
- If WhisperKit's API drifts from what this doc assumes, **trust its current README** over this doc — section 6's protocol shields the rest of the app from API churn.
- Ask the user before enabling any dependency not listed in section 5.
- If a technical decision needs to change (e.g., audio mixing approach is impractical), **write the proposed change to a `DEVIATIONS.md`** file at the project root, explain the reason, and pause for approval — don't silently diverge from this plan.
- Do **not** add features listed in "out of scope" (section 1).
