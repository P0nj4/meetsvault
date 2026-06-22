# Meeting-Name Field in Audio-Source Dialog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional "Meeting name" text field to the audio-source dialog so recordings started from the menu bar (and editable for URL-scheme starts) get a meaningful title instead of `untitled`.

**Architecture:** Extend the existing `CaptureSourceWindow` SwiftUI dialog (already shown on every Start) with a pre-fillable, editable name field. The dialog's `onStart` closure changes to return `(String?, CaptureMode)`. `MenuBarController.presentCaptureSourcePrompt(title:)` passes the incoming title as the field's initial value and uses the dialog's returned name for `recorder.start`.

**Tech Stack:** Swift, SwiftUI (`TextField`, `@State`, `@FocusState`), AppKit (`NSWindow`), Xcode (`xcodebuild`).

## Global Constraints

- macOS 15+, Apple Silicon. The dialog is SwiftUI hosted in an `NSWindow`; the rest of the app is AppKit.
- No new Swift files are created → do NOT run `xcodegen generate`.
- Name field is **optional**: Start stays gated only on a source being selected. Blank/whitespace name → `nil` → existing `untitled`/`Untitled` fallback (no downstream changes).
- URL-scheme `?title=` must pre-fill the field and remain editable (no automation regression: the provided title still becomes the recording title).
- User-facing flow change → update `README.md`, `docs/USER_MANUAL.md`, and `docs/USER_MANUAL.es.md` in the same change (per `CLAUDE.md`). Spanish mirrors English.

---

### Task 1: Add the meeting-name field to the dialog and wire it through

**Files:**
- Modify: `MeetsVault/MeetsVault/UI/CaptureSourceWindow.swift` (`CaptureSourceWindowController.init`, `CaptureSourceView`)
- Modify: `MeetsVault/MeetsVault/MenuBar/MenuBarController.swift:245-271` (`presentCaptureSourcePrompt`)

**Interfaces:**
- Produces: `CaptureSourceWindowController(initialTitle: String?, onStart: @escaping (String?, CaptureMode) -> Void, onCancel: @escaping () -> Void)`
- Produces: `CaptureSourceView(initialTitle: String?, onStart: @escaping (String?, CaptureMode) -> Void, onCancel: @escaping () -> Void)` — passes the trimmed name (`nil` if blank) and selected mode on Start.
- Consumes: `MenuBarController.recorder.start(title: String?, captureMode: CaptureMode)` (unchanged signature).

- [ ] **Step 1: Update `CaptureSourceWindowController.init`**

In `CaptureSourceWindow.swift`, replace the `convenience init`:

```swift
    convenience init(
        initialTitle: String?,
        onStart: @escaping (String?, CaptureMode) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let view = CaptureSourceView(initialTitle: initialTitle, onStart: onStart, onCancel: onCancel)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 460, height: 390))
        window.styleMask = [.titled, .closable]
        window.title = "Audio source"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }
```

(Only changes vs. current: new `initialTitle` param, `onStart` type is `(String?, CaptureMode) -> Void`, the view init call, and height `320` → `390` to fit the new field.)

- [ ] **Step 2: Update `CaptureSourceView` — declarations and initializer**

Replace the top of `private struct CaptureSourceView: View` (its stored properties and add an explicit init) so it reads:

```swift
private struct CaptureSourceView: View {
    let onStart: (String?, CaptureMode) -> Void
    let onCancel: () -> Void

    @State private var meetingName: String
    @State private var selected: CaptureMode?
    @FocusState private var nameFocused: Bool

    init(
        initialTitle: String?,
        onStart: @escaping (String?, CaptureMode) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onStart = onStart
        self.onCancel = onCancel
        _meetingName = State(initialValue: initialTitle ?? "")
    }
```

- [ ] **Step 3: Update `CaptureSourceView.body` — add the field and the new onStart call**

Replace the `body` of `CaptureSourceView` with:

```swift
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meeting name")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("Optional — e.g. Weekly Standup", text: $meetingName)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)
                }

                Text("How are you listening to the meeting?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    SourceCard(
                        symbol: "headphones",
                        title: "Headphones",
                        subtitle: "Records your voice and the call",
                        isSelected: selected == .micAndSystem
                    ) {
                        selected = .micAndSystem
                    }

                    SourceCard(
                        symbol: "laptopcomputer",
                        title: "Laptop speakers",
                        subtitle: "Records only your microphone",
                        isSelected: selected == .micOnly
                    ) {
                        selected = .micOnly
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Spacer()
                Button("Start Recording") {
                    if let mode = selected {
                        let trimmed = meetingName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onStart(trimmed.isEmpty ? nil : trimmed, mode)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected == nil)
            }
            .padding(16)
        }
        .onAppear { nameFocused = true }
    }
```

(`SourceCard` and `brandColor` are unchanged — leave them as-is.)

- [ ] **Step 4: Update `MenuBarController.presentCaptureSourcePrompt`**

In `MenuBarController.swift`, replace the `CaptureSourceWindowController(...)` construction (lines 250-268) so the dialog receives `initialTitle` and the returned name is used for `recorder.start`:

```swift
        let wc = CaptureSourceWindowController(
            initialTitle: title,
            onStart: { [weak self] name, mode in
                guard let self else { return }
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

(Only changes: `initialTitle: title` added; the closure param is now `name, mode`; `recorder.start(title: name, …)` instead of `title: title`. The early-return reuse of an existing `captureSourceWindowController` at lines 246-249 is unchanged.)

- [ ] **Step 5: Build to verify it compiles**

Run:

```bash
xcodebuild -project MeetsVault.xcodeproj -scheme MeetsVault -configuration Release -destination "platform=macOS,arch=arm64" -derivedDataPath build build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Run the existing unit tests**

`FilenameBuilder` already covers the `nil`/empty → `untitled` path; no new test logic is added (the trim-to-`nil` decision lives in the SwiftUI view, which has no unit-test target). Confirm the suite still passes:

```bash
xcodebuild test -project MeetsVault.xcodeproj -scheme MeetsVault -destination "platform=macOS,arch=arm64" 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Manual verification (cannot be done headlessly — defer to controller)**

Launch `build/Build/Products/Release/MeetsVault.app` and check:
1. Menu-bar Start → dialog shows an empty "Meeting name" field with focus → type "Team Sync", pick a source, Start → transcript/filename uses "Team Sync".
2. Menu-bar Start → leave name blank → output saved as `untitled`.
3. `open "meetsvault://start?title=Weekly%20Standup"` → field pre-filled "Weekly Standup", editable → Start uses it.

- [ ] **Step 8: Commit**

```bash
git add MeetsVault/MeetsVault/UI/CaptureSourceWindow.swift MeetsVault/MeetsVault/MenuBar/MenuBarController.swift
git commit -m "ask for meeting name in the audio-source dialog on start

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Update user-facing docs

**Files:**
- Modify: `README.md` (Menu bar usage ~lines 73-78; URL scheme ~lines 84-90)
- Modify: `docs/USER_MANUAL.md` (line 93; section 5.1 lines 95-102)
- Modify: `docs/USER_MANUAL.es.md` (line 93; section 5.1 lines 95-102)

**Interfaces:**
- Consumes: behavior implemented in Task 1.

- [ ] **Step 1: Update `README.md` menu-bar section**

Replace line 73:

```markdown
Click the waveform icon → **Start Recording**. A small dialog opens with an optional **Meeting name** field and asks how you're listening to the meeting:
```

Replace line 78:

```markdown
Optionally type a meeting name (it becomes the transcript title and filename; left blank, the recording is saved as `untitled`), pick a source, and confirm **Start Recording**. The icon turns red while recording. Click **Stop Recording** when done — transcription starts automatically.
```

- [ ] **Step 2: Update `README.md` URL scheme note**

Immediately after the URL-scheme code block (after the closing ```` ``` ```` on line 90), add this line:

```markdown

> The `title` you pass pre-fills the **Meeting name** field in the dialog, where you can edit it before starting.
```

- [ ] **Step 3: Update `docs/USER_MANUAL.md` line 93**

Replace line 93:

```markdown
- **Start Recording** — opens a small **Audio source** dialog (see section 5.1) where you name the meeting and choose how the meeting is being played back. Recording begins after you confirm.
```

- [ ] **Step 4: Update `docs/USER_MANUAL.md` section 5.1**

Insert this paragraph between the "Laptop speakers" bullet (line 100) and the "Pick the option…" paragraph (line 102) — i.e. as its own paragraph after the bullet list:

```markdown
At the top of this dialog is an optional **Meeting name** field. Whatever you type becomes the transcript's title and filename; leave it blank and the recording is saved as `untitled`. When you start from the URL scheme with a `title`, this field is pre-filled with that title and you can edit it before starting.
```

- [ ] **Step 5: Update `docs/USER_MANUAL.es.md` line 93 (Spanish mirror)**

Replace line 93:

```markdown
- **Start Recording** — abre un pequeño diálogo de **Fuente de audio** (ver sección 5.1) donde nombrás la reunión y elegís cómo estás escuchando la reunión. La grabación comienza después de que confirmás.
```

- [ ] **Step 6: Update `docs/USER_MANUAL.es.md` section 5.1 (Spanish mirror)**

Insert this paragraph between the "Laptop speakers" bullet (line 100) and the "Elegí la opción…" paragraph (line 102):

```markdown
En la parte superior de este diálogo hay un campo opcional **Meeting name** (nombre de la reunión). Lo que escribas se convierte en el título y el nombre de archivo de la transcripción; si lo dejás en blanco, la grabación se guarda como `untitled`. Cuando iniciás desde el esquema de URL con un `title`, este campo se rellena con ese título y podés editarlo antes de empezar.
```

- [ ] **Step 7: Commit**

```bash
git add README.md docs/USER_MANUAL.md docs/USER_MANUAL.es.md
git commit -m "document meeting-name field in the audio-source dialog

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** name field added (Task 1 Steps 2-3), optional/Start gating unchanged (Step 3 `.disabled(selected == nil)`), initial focus (Step 3 `.onAppear`), pre-fill from `initialTitle` (Step 2 init), trim-to-`nil` (Step 3 Start action), wiring uses dialog name (Step 4), URL-scheme pre-fill via existing routing (unchanged, covered by `initialTitle: title`), downstream untouched, docs in all three files (Task 2). All covered.
- **Placeholder scan:** none — all code and doc text shown in full.
- **Type consistency:** `onStart: (String?, CaptureMode) -> Void` and `initialTitle: String?` used identically in `CaptureSourceWindowController`, `CaptureSourceView`, and the `MenuBarController` call site. `recorder.start(title:captureMode:)` signature unchanged; `name` (`String?`) feeds its `title`.
