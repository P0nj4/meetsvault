# URL Stop Confirmation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `meetsvault://stop` show a Stop/Continue confirmation prompt while recording, and silently ignore it when not recording.

**Architecture:** Add a `presentStopPrompt` closure to `URLSchemeHandler` (mirroring the existing `presentStartPrompt`). `AppDelegate` routes it to a new `MenuBarController.presentStopConfirmation()` that shows an `NSAlert`. Only "Stop recording" calls `recorder.stop()`. The menu-bar Stop item is untouched.

**Tech Stack:** Swift, AppKit (`NSAlert`), Xcode (`xcodebuild`).

## Global Constraints

- macOS 15+, Apple Silicon. AppKit only (no SwiftUI windows).
- No new Swift files are created, so `xcodegen generate` is NOT required for this change.
- User-facing URL-scheme behavior changes → `README.md`, `docs/USER_MANUAL.md`, and `docs/USER_MANUAL.es.md` must be updated in the same change (per `CLAUDE.md`).
- Spanish manual is a mirror of the English one.

---

### Task 1: Confirmation prompt on URL-scheme stop

**Files:**
- Modify: `MeetsVault/MeetsVault/URLScheme/URLSchemeHandler.swift` (`handle` signature + `stop` case, lines 4-39)
- Modify: `MeetsVault/MeetsVault/AppDelegate.swift` (`handleGetURLEvent`, lines 54-56)
- Modify: `MeetsVault/MeetsVault/MenuBar/MenuBarController.swift` (add flag near line 23; add method near `presentCaptureSourcePrompt` at line 244)

**Interfaces:**
- Produces: `URLSchemeHandler.handle(_ url: URL, recorder: AudioRecorder?, presentStartPrompt: ((String?) -> Void)?, presentStopPrompt: (() -> Void)?)`
- Produces: `MenuBarController.presentStopConfirmation()` — main-thread, shows the modal.

- [ ] **Step 1: Add the `presentStopPrompt` parameter to `URLSchemeHandler.handle`**

In `URLSchemeHandler.swift`, change the signature:

```swift
    static func handle(
        _ url: URL,
        recorder: AudioRecorder?,
        presentStartPrompt: ((String?) -> Void)?,
        presentStopPrompt: (() -> Void)?
    ) {
```

- [ ] **Step 2: Rewrite the `stop` case to be silent-when-idle and prompt-when-recording**

Replace the existing `case "stop":` block:

```swift
        case "stop":
            guard let recorder else { return }
            guard recorder.state == .recording else {
                NSLog("[MeetsVault] URL stop ignored — not recording")
                return
            }
            DispatchQueue.main.async {
                presentStopPrompt?()
            }
```

(The previous `postNotification(title: "Nothing to stop", ...)` and the direct `Task { await recorder.stop() }` are both removed.)

- [ ] **Step 3: Update the call site in `AppDelegate.handleGetURLEvent`**

In `AppDelegate.swift`, replace the trailing-closure call (lines 54-56) with explicit labels so both closures bind correctly:

```swift
        URLSchemeHandler.handle(
            url,
            recorder: menuBarController?.recorder,
            presentStartPrompt: { [weak self] title in
                self?.menuBarController?.presentCaptureSourcePrompt(title: title)
            },
            presentStopPrompt: { [weak self] in
                self?.menuBarController?.presentStopConfirmation()
            }
        )
```

- [ ] **Step 4: Add the re-entrancy flag to `MenuBarController`**

In `MenuBarController.swift`, add next to the other `private var` declarations (after line 23, `private var isDownloadingModel = false`):

```swift
    private var isPresentingStopConfirmation = false
```

- [ ] **Step 5: Add `presentStopConfirmation()` to `MenuBarController`**

In `MenuBarController.swift`, add this method directly after `presentCaptureSourcePrompt(title:)` (after its closing brace at line 270):

```swift
    func presentStopConfirmation() {
        guard !isPresentingStopConfirmation else { return }
        isPresentingStopConfirmation = true
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Stop recording?"
        alert.informativeText = "MeetsVault is currently recording. Stop and transcribe now, or keep recording?"
        alert.addButton(withTitle: "Stop recording")
        alert.addButton(withTitle: "Continue recording")
        let response = alert.runModal()
        isPresentingStopConfirmation = false
        if response == .alertFirstButtonReturn {
            Task { [weak self] in
                await self?.recorder.stop()
            }
        }
    }
```

- [ ] **Step 6: Build to verify it compiles**

Run:

```bash
xcodebuild -project MeetsVault.xcodeproj -scheme MeetsVault -configuration Release -destination "platform=macOS,arch=arm64" -derivedDataPath build build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Manual verification**

There is no unit test for `URLSchemeHandler` (it is UI-closure wiring; this change adds no testable pure logic). Verify by hand against the built app (`build/Build/Products/Release/MeetsVault.app` — launch it, grant nothing new):

1. While **idle**: run `open "meetsvault://stop"` → nothing happens; Console shows `URL stop ignored — not recording`; no notification, no alert.
2. While **recording**: run `open "meetsvault://stop"` → an alert appears titled "Stop recording?". Click **Continue recording** → recording keeps going (menu-bar icon stays in recording state).
3. While **recording**: run `open "meetsvault://stop"`, click **Stop recording** → recording stops and transcription begins (icon enters transcribing state).
4. While **recording**: run `open "meetsvault://stop"` twice quickly → only one alert is shown.

- [ ] **Step 8: Commit**

```bash
git add MeetsVault/MeetsVault/URLScheme/URLSchemeHandler.swift MeetsVault/MeetsVault/AppDelegate.swift MeetsVault/MeetsVault/MenuBar/MenuBarController.swift
git commit -m "prompt to confirm stop when meetsvault://stop fires during recording

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Update user-facing docs

**Files:**
- Modify: `README.md` (URL scheme block near line 88)
- Modify: `docs/USER_MANUAL.md` ("Stop the current recording" near line 202)
- Modify: `docs/USER_MANUAL.es.md` ("Detener la grabación actual" near line 202)

**Interfaces:**
- Consumes: behavior implemented in Task 1.

- [ ] **Step 1: Update `README.md`**

Replace the `# Stop and transcribe` comment in the URL-scheme code block (line 88) so the comment reads:

```bash
# Stop and transcribe (asks to confirm if a recording is in progress; ignored otherwise)
open 'meetsvault://stop'
```

- [ ] **Step 2: Update `docs/USER_MANUAL.md`**

Replace the "Stop the current recording:" heading and its code block (lines 202-206) with:

```markdown
**Stop the current recording:**

```
meetsvault://stop
```

If a recording is in progress, MeetsVault brings up a confirmation prompt — choose **Stop recording** to stop and transcribe, or **Continue recording** to keep going. If nothing is recording, the URL is ignored.
```

- [ ] **Step 3: Update `docs/USER_MANUAL.es.md` (mirror of English)**

Replace the "Detener la grabación actual:" heading and its code block (lines 202-206) with:

```markdown
**Detener la grabación actual:**

```
meetsvault://stop
```

Si hay una grabación en curso, MeetsVault muestra un cuadro de confirmación — elige **Stop recording** para detener y transcribir, o **Continue recording** para seguir grabando. Si no hay nada grabándose, la URL se ignora.
```

- [ ] **Step 4: Commit**

```bash
git add README.md docs/USER_MANUAL.md docs/USER_MANUAL.es.md
git commit -m "document confirmation prompt for meetsvault://stop

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** silent-when-idle (Task 1 Step 2), prompt-when-recording with Stop/Continue (Steps 2, 5), Stop→transcribe / Continue→no-op (Step 5), re-entrancy guard (Steps 4-5), `NSApp.activate` (Step 5), menu-bar Stop unchanged (not touched), docs in all three files (Task 2). All covered.
- **Placeholder scan:** none — all code shown in full.
- **Type consistency:** `presentStopPrompt: (() -> Void)?` and `presentStopConfirmation()` used identically across `URLSchemeHandler`, `AppDelegate`, and `MenuBarController`. `.alertFirstButtonReturn` corresponds to the first-added button "Stop recording".
