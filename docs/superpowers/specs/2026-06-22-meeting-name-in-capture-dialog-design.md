# Design: meeting-name field in the audio-source dialog

Date: 2026-06-22

## Problem

Starting a recording from the menu bar calls `presentCaptureSourcePrompt(title: nil)`, so the recording has no title. Downstream this produces a `untitled` filename (`FilenameBuilder.makeSlug` → `"untitled"`) and an `Untitled` frontmatter title (`TranscriptWriter`). The user wants to name the meeting at start time so menu-bar-started recordings get a meaningful name.

The audio-source window (`CaptureSourceWindow`, "How are you listening to the meeting?") already appears on every Start — both menu-bar and URL-scheme — to pick `CaptureMode`. The fix is to add a meeting-name field to that existing dialog rather than introduce a separate prompt.

## Desired behavior

- The audio-source dialog gains a **"Meeting name"** text field at the top, above the source choice.
- The field is **optional**: Start remains gated only on a source being selected. A blank name falls back to `untitled` (unchanged behavior).
- The field receives initial keyboard focus so the user can type immediately.
- **Menu-bar Start** → dialog opens with an empty name field → typed name becomes the recording title.
- **URL-scheme Start with `?title=...`** → dialog opens with the field **pre-filled and editable**; the field value (pre-filled or edited) is the title used. This matches today's result for the provided-title case (the title still becomes the recording title) with no automation regression — URL-scheme start already requires the user to pick a source in this same window.

## Components & changes

### `CaptureSourceWindow.swift`

`CaptureSourceView`:
- Add `let initialTitle: String?` and `@State private var meetingName: String` initialized from `initialTitle ?? ""`.
- Add a `TextField("Meeting name", text: $meetingName)` block above the "How are you listening to the meeting?" section. Give it initial focus (`@FocusState`).
- Change the `onStart` closure type from `(CaptureMode) -> Void` to `(String?, CaptureMode) -> Void`. On Start, pass the trimmed name (`nil` if empty after trimming whitespace) and the selected mode.

`CaptureSourceWindowController`:
- `init` gains `initialTitle: String?`, forwarded into `CaptureSourceView`.
- `onStart` parameter type updated to `(String?, CaptureMode) -> Void`.

### `MenuBarController.presentCaptureSourcePrompt(title:)` (`MenuBarController.swift`, ~line 244)

- Pass the incoming `title` as `initialTitle` when constructing `CaptureSourceWindowController`.
- In the `onStart` closure, use the **name returned from the dialog** for `recorder.start(title:captureMode:)` instead of the captured `title` parameter. (The captured `title` is now only the initial field value.)

### Downstream — unchanged

`FilenameBuilder.build(title:date:)` and `TranscriptWriter.write(...)` already accept `String?` and handle `nil`/empty → `untitled` / `Untitled`. No changes.

### URL-scheme path — unchanged

`URLSchemeHandler` `start` case and `AppDelegate` already route the URL `title` through `presentCaptureSourcePrompt(title:)`. With the change above, that title becomes the field's initial value. No edits needed in those files.

## Data flow

```
Menu-bar Start  → presentCaptureSourcePrompt(title: nil)
URL start ?title=Foo → presentCaptureSourcePrompt(title: "Foo")
        ↓
CaptureSourceWindowController(initialTitle:, onStart:)
        ↓  field pre-filled with initialTitle, editable, optional
onStart(name: String?, mode: CaptureMode)
        ↓
recorder.start(title: name, captureMode: mode)
        ↓
FilenameBuilder / TranscriptWriter  (name ?? untitled/Untitled)
```

## Error handling / edge cases

- Blank or whitespace-only name → trimmed to `nil` → `untitled` fallback (same as today).
- URL `title` present → pre-filled and editable; user may clear it (→ `untitled`) or edit it.
- Cancel/close window → `onCancel` path unchanged; no recording starts.

## Testing

- `FilenameBuilder` already has unit tests for the `nil`/empty → `untitled` path; no new logic there.
- The trim-to-`nil` decision lives in the SwiftUI view, which has no unit-test target. Verify by build + manual check:
  - Menu-bar Start → type "Team Sync" → recording/transcript named accordingly.
  - Menu-bar Start → leave name blank → output is `untitled`.
  - `open "meetsvault://start?title=Weekly%20Standup"` → field pre-filled "Weekly Standup", editable → Start uses it.

## Docs

User-facing (the Start flow now asks for a name). Update in the same change:
- `README.md` (Usage / start flow)
- `docs/USER_MANUAL.md`
- `docs/USER_MANUAL.es.md` (Spanish mirror)

## Out of scope

- Making the name required.
- Read-only or skipped name field for URL-provided titles (decided: pre-fill + editable).
- Persisting a default name.
- Any change to the stop/transcription flow.
