# Remember Last Capture Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the user starts a recording, persist which capture mode they picked (Headphones vs. Laptop speakers); the next time the audio-source dialog opens, preselect that same option instead of showing no selection.

**Architecture:** Give `CaptureMode` a `String` raw value so it round-trips through `UserDefaults`. Add a `Settings.lastCaptureMode: CaptureMode?` property backed by that raw value. `MenuBarController.presentCaptureSourcePrompt` reads `Settings.shared.lastCaptureMode` and passes it into `CaptureSourceWindowController`/`CaptureSourceView` as the initial `@State` selection; on a successful Start, the closure writes the chosen mode back to `Settings.shared.lastCaptureMode` before starting the recorder.

**Tech Stack:** Swift, Foundation (`UserDefaults`), SwiftUI (`@State`), AppKit (`NSWindow`), Xcode (`xcodebuild`), XCTest.

## Global Constraints

- macOS 15+, Apple Silicon.
- No new Swift files are created → do NOT run `xcodegen generate`.
- First launch ever (no prior selection) must still show the dialog with **nothing** preselected and Start disabled — same as today. Only a previously-completed Start seeds a preselection.
- Persistence key lives in the existing `com.germanpereyra.meetsvault` `UserDefaults.standard` domain, following the pattern already used by `selectedModelName` / `transcriptionLanguage` in `Settings.swift`.
- User-facing behavior change → update `README.md`, `docs/USER_MANUAL.md`, and `docs/USER_MANUAL.es.md` in the same change (per `CLAUDE.md`). Spanish mirrors English.

---

### Task 1: Make `CaptureMode` persistable and add `Settings.lastCaptureMode`

**Files:**
- Modify: `MeetsVault/MeetsVault/Recording/CaptureMode.swift`
- Modify: `MeetsVault/MeetsVault/Settings/Settings.swift`
- Test: `MeetsVaultTests/SettingsTests.swift` (new)

**Interfaces:**
- Produces: `enum CaptureMode: String { case micOnly, micAndSystem }` — same two cases as today, now `RawRepresentable` with `String` raw values (`"micOnly"`, `"micAndSystem"`). Existing `==` comparisons (e.g. `selected == .micAndSystem` in `CaptureSourceWindow.swift`) keep working unchanged.
- Produces: `Settings.shared.lastCaptureMode: CaptureMode?` — `nil` when nothing has ever been saved; otherwise the last value written.
- Consumes: `Settings.shared.defaults` (existing `UserDefaults.standard` instance already private to `Settings`).

- [ ] **Step 1: Write the failing test**

Create `MeetsVaultTests/SettingsTests.swift`:

```swift
import XCTest
@testable import MeetsVault

final class SettingsTests: XCTestCase {

    override func tearDown() {
        Settings.shared.lastCaptureMode = nil
        super.tearDown()
    }

    func testLastCaptureModeDefaultsToNil() {
        Settings.shared.lastCaptureMode = nil
        XCTAssertNil(Settings.shared.lastCaptureMode)
    }

    func testLastCaptureModeRoundTripsMicOnly() {
        Settings.shared.lastCaptureMode = .micOnly
        XCTAssertEqual(Settings.shared.lastCaptureMode, .micOnly)
    }

    func testLastCaptureModeRoundTripsMicAndSystem() {
        Settings.shared.lastCaptureMode = .micAndSystem
        XCTAssertEqual(Settings.shared.lastCaptureMode, .micAndSystem)
    }

    func testLastCaptureModeOverwritesPreviousValue() {
        Settings.shared.lastCaptureMode = .micOnly
        Settings.shared.lastCaptureMode = .micAndSystem
        XCTAssertEqual(Settings.shared.lastCaptureMode, .micAndSystem)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault -destination "platform=macOS,arch=arm64" -only-testing:MeetsVaultTests/SettingsTests 2>&1 | tail -30
```

Expected: build failure — `Settings` has no member `lastCaptureMode`, and `CaptureMode` does not conform to `Equatable`-requiring-context needed by `XCTAssertEqual` in the way the test needs (or a "cannot find" compile error). Either way, it must NOT compile/pass yet.

- [ ] **Step 3: Add the raw value to `CaptureMode`**

Replace the full contents of `MeetsVault/MeetsVault/Recording/CaptureMode.swift`:

```swift
import Foundation

enum CaptureMode: String {
    /// Laptop speakers — only the microphone is recorded, no system audio.
    case micOnly
    /// Headphones — microphone + system audio captured in parallel (current behavior).
    case micAndSystem
}
```

- [ ] **Step 4: Add `lastCaptureMode` to `Settings`**

In `MeetsVault/MeetsVault/Settings/Settings.swift`, add a new key to the `Key` enum:

```swift
    private enum Key {
        static let selectedModelName = "selectedModelName"
        static let transcriptionLanguage = "transcriptionLanguage"
        static let downloadedModels = "downloadedModels"
        static let meetingsDirectoryPath = "meetingsDirectoryPath"
        static let lastCaptureMode = "lastCaptureMode"
    }
```

Then add this property (next to `transcriptionLanguage`, before `downloadedModels`):

```swift
    var lastCaptureMode: CaptureMode? {
        get {
            guard let raw = defaults.string(forKey: Key.lastCaptureMode) else { return nil }
            return CaptureMode(rawValue: raw)
        }
        set { defaults.set(newValue?.rawValue, forKey: Key.lastCaptureMode) }
    }
```

(`defaults.set(nil, forKey:)` removes the key, which is exactly what's needed for the `nil`-reset path used by the test's `tearDown`.)

- [ ] **Step 5: Run the test to verify it passes**

Run:

```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault -destination "platform=macOS,arch=arm64" -only-testing:MeetsVaultTests/SettingsTests 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **`, all 4 `SettingsTests` pass.

- [ ] **Step 6: Run the full test suite to check for regressions**

Run:

```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault -destination "platform=macOS,arch=arm64" 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add MeetsVault/MeetsVault/Recording/CaptureMode.swift MeetsVault/MeetsVault/Settings/Settings.swift MeetsVaultTests/SettingsTests.swift
git commit -m "persist last-used capture mode in Settings

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Preselect the audio-source dialog and save the choice on Start

**Files:**
- Modify: `MeetsVault/MeetsVault/UI/CaptureSourceWindow.swift`
- Modify: `MeetsVault/MeetsVault/MenuBar/MenuBarController.swift:245-271` (`presentCaptureSourcePrompt`)

**Interfaces:**
- Consumes: `Settings.shared.lastCaptureMode: CaptureMode?` (Task 1).
- Consumes: `Settings.shared.lastCaptureMode = CaptureMode` setter (Task 1).
- Produces: `CaptureSourceWindowController(initialTitle: String?, initialMode: CaptureMode?, onStart: @escaping (String?, CaptureMode) -> Void, onCancel: @escaping () -> Void)`.
- Produces: `CaptureSourceView(initialTitle: String?, initialMode: CaptureMode?, onStart: @escaping (String?, CaptureMode) -> Void)`.

- [ ] **Step 1: Update `CaptureSourceWindowController.init` to accept and forward `initialMode`**

In `CaptureSourceWindow.swift`, replace the `init`:

```swift
    init(
        initialTitle: String?,
        initialMode: CaptureMode?,
        onStart: @escaping (String?, CaptureMode) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onCancel = onCancel
        let view = CaptureSourceView(initialTitle: initialTitle, initialMode: initialMode, onStart: onStart)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 460, height: 390))
        window.styleMask = [.titled, .closable]
        window.title = "Audio source"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
    }
```

(Only change vs. current: new `initialMode: CaptureMode?` parameter, forwarded into `CaptureSourceView(...)`.)

- [ ] **Step 2: Update `CaptureSourceView.init` to seed `selected` from `initialMode`**

In `CaptureSourceWindow.swift`, replace the `CaptureSourceView` init:

```swift
    init(
        initialTitle: String?,
        initialMode: CaptureMode?,
        onStart: @escaping (String?, CaptureMode) -> Void
    ) {
        self.onStart = onStart
        _meetingName = State(initialValue: initialTitle ?? "")
        _selected = State(initialValue: initialMode)
    }
```

(`@State private var selected: CaptureMode?` declaration above it is unchanged — it already defaults to `nil` when no initializer sets it, and now the init sets it explicitly.)

- [ ] **Step 3: Update `MenuBarController.presentCaptureSourcePrompt` to pass and persist the mode**

In `MenuBarController.swift`, replace the `CaptureSourceWindowController(...)` construction:

```swift
        let wc = CaptureSourceWindowController(
            initialTitle: title,
            initialMode: Settings.shared.lastCaptureMode,
            onStart: { [weak self] name, mode in
                guard let self else { return }
                Settings.shared.lastCaptureMode = mode
                self.captureSourceWindowController?.closeWindow()
                self.captureSourceWindowController = nil
                Task {
                    do {
                        try await self.recorder.start(title: name, captureMode: mode)
                    } catch {
                        NSLog("[MeetsVault] Start failed: %@", error.localizedDescription)
                        let message = error.localizedDescription
                        await MainActor.run { self.showError(message) }
                    }
                }
            },
            onCancel: { [weak self] in
                self?.captureSourceWindowController = nil
            }
        )
```

(Only changes: `initialMode: Settings.shared.lastCaptureMode` added, and `Settings.shared.lastCaptureMode = mode` added as the first line of the `onStart` closure — saved before anything else so it's persisted even if `recorder.start` later throws.)

- [ ] **Step 4: Build to verify it compiles**

Run:

```bash
xcodebuild -project MeetsVault.xcodeproj -scheme MeetsVault -configuration Release -destination "platform=macOS,arch=arm64" -derivedDataPath build build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Run the full test suite**

Run:

```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault -destination "platform=macOS,arch=arm64" 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Manual verification (SwiftUI selection state has no unit-test target — verify by running the app)**

Launch `build/Build/Products/Release/MeetsVault.app` and check:
1. If this is a fresh install (no prior recordings ever started on this machine), click **Start Recording** → dialog opens with neither card selected and **Start Recording** disabled — same as before this change.
2. Pick **Headphones**, type any meeting name, click **Start Recording** → recording starts. Stop it (recording can be very short).
3. Click **Start Recording** again → dialog opens with **Headphones** already highlighted/selected and **Start Recording** already enabled without clicking a card.
4. This time pick **Laptop speakers** instead, click **Start Recording** → recording starts. Stop it.
5. Click **Start Recording** again → dialog opens with **Laptop speakers** now preselected (confirms the saved mode updates on every Start, not just the first).
6. Quit and relaunch MeetsVault, click **Start Recording** → the last-picked mode (**Laptop speakers** from step 5) is still preselected (confirms persistence survives app restart, not just in-memory state).

- [ ] **Step 7: Commit**

```bash
git add MeetsVault/MeetsVault/UI/CaptureSourceWindow.swift MeetsVault/MeetsVault/MenuBar/MenuBarController.swift
git commit -m "preselect the audio-source dialog with the last-used capture mode

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Update user-facing docs

**Files:**
- Modify: `README.md` (lines 73-76)
- Modify: `docs/USER_MANUAL.md` (line 97)
- Modify: `docs/USER_MANUAL.es.md` (line 97)

**Interfaces:**
- Consumes: behavior implemented in Task 2.

- [ ] **Step 1: Update `README.md`**

Replace line 73:

```markdown
Click the waveform icon → **Start Recording**. A small dialog opens with an optional **Meeting name** field and asks how you're listening to the meeting (the option you picked last time is preselected):
```

- [ ] **Step 2: Update `docs/USER_MANUAL.md` section 5.1**

Replace line 97:

```markdown
Every time you start a recording, MeetsVault asks how you're listening to the meeting. The dialog preselects whichever option you picked the last time you started a recording, so most of the time you can just confirm. The very first time you ever use MeetsVault, nothing is preselected and the button stays disabled until you pick one.
```

- [ ] **Step 3: Update `docs/USER_MANUAL.es.md` section 5.1 (Spanish mirror)**

Replace line 97:

```markdown
Cada vez que iniciás una grabación, MeetsVault pregunta cómo estás escuchando la reunión. El diálogo preselecciona la opción que elegiste la última vez que iniciaste una grabación, así que la mayoría de las veces alcanza con confirmar. La primerísima vez que usás MeetsVault no hay nada preseleccionado y el botón queda deshabilitado hasta que elegís una opción.
```

- [ ] **Step 4: Commit**

```bash
git add README.md docs/USER_MANUAL.md docs/USER_MANUAL.es.md
git commit -m "document that the audio-source dialog remembers the last capture mode

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** "save the latest selection (if there is any)" → Task 1 (`Settings.lastCaptureMode`, `nil` when never set) + Task 2 Step 3 (saved on every successful Start). "next time the modal is opened, the buttons get preselected with the latest selected option" → Task 2 Steps 1-3 (`initialMode` threaded from `Settings` into `CaptureSourceView`'s `@State`). First-ever-launch no-default behavior preserved → Task 2 Step 6 manual check 1, and `Settings.lastCaptureMode` returns `nil` until first write (Task 1 test `testLastCaptureModeDefaultsToNil`). Docs updated in all three required files → Task 3. All requirements covered.
- **Placeholder scan:** none — every step shows complete code, exact commands, and expected output.
- **Type consistency:** `CaptureMode: String` raw value used identically in `Settings.lastCaptureMode` (Task 1) and in `CaptureSourceWindowController`/`CaptureSourceView`'s `initialMode: CaptureMode?` parameter (Task 2). `onStart: (String?, CaptureMode) -> Void` signature is unchanged from the existing code, so `MenuBarController`'s closure signature in Task 2 Step 3 matches what Task 2 Steps 1-2 produce.
