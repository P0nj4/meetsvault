# Design: confirmation prompt for `meetsvault://stop`

Date: 2026-06-22

## Problem

Today `meetsvault://stop` (handled in `URLSchemeHandler.handle`, `stop` case) behaves as:

- `recorder.state != .recording` → posts a "Nothing to stop" notification.
- `recorder.state == .recording` → calls `recorder.stop()` **directly**, with no confirmation.

A stop URL can be fired accidentally (automation, a mistyped Shortcut, a stray link), and there is no chance to cancel before the recording ends and transcription begins. We want a confirmation step on the URL-scheme stop path.

Note: because the confirmation is a modal prompt, a URL-scheme `stop` will only take effect if a human is present to click. This is intentional for this use case; truly headless stop is out of scope.

## Desired behavior

URL-scheme `stop`:

- `recorder.state != .recording` (idle or transcribing) → **fully silent**: `NSLog` only. No notification, no prompt. (Removes the current "Nothing to stop" notification.)
- `recorder.state == .recording` → show a modal **Stop / Continue** confirmation:
  - **Stop recording** → stop and begin transcription (same path as the menu-bar Stop item).
  - **Continue recording** → do nothing; recording continues.

The menu-bar "Stop Recording" item is **unchanged** — it still stops directly with no prompt. The confirmation applies only to the URL-scheme path.

## Components & changes

### `URLSchemeHandler.handle` (`MeetsVault/MeetsVault/URLScheme/URLSchemeHandler.swift`)

- Add a `presentStopPrompt: (() -> Void)?` parameter, mirroring the existing `presentStartPrompt`.
- `stop` case:
  - Replace the `state == .recording` guard's else branch (which posts "Nothing to stop") with a silent `NSLog` and `return`.
  - When `state == .recording`, call `presentStopPrompt?()` on the main thread instead of `Task { await recorder.stop() }`.

### `AppDelegate.handleGetURLEvent` (`MeetsVault/MeetsVault/AppDelegate.swift`)

- Pass a `presentStopPrompt` closure that calls `menuBarController?.presentStopConfirmation()`.

### `MenuBarController.presentStopConfirmation()` (new — `MeetsVault/MeetsVault/MenuBar/MenuBarController.swift`)

- Runs on the main thread.
- Re-entrancy guard: if a stop confirmation alert is already showing, no-op (a repeated URL does not stack a second alert). Tracked with a `private var isPresentingStopConfirmation = false` flag (or equivalent).
- `NSApp.activate(ignoringOtherApps: true)` so the alert surfaces (the app runs as a menu-bar/background agent).
- Build an `NSAlert`:
  - `messageText`: "Stop recording?"
  - `informativeText`: "MeetsVault is currently recording. Stop and transcribe now, or keep recording?"
  - First button (default): "Stop recording"
  - Second button (cancel): "Continue recording"
- On "Stop recording" → `Task { [weak self] in await self?.recorder.stop() }` (same call as `stopRecording`).
- On "Continue recording" → do nothing.
- Clear the re-entrancy flag after the modal returns.

## Data flow

```
URL meetsvault://stop
  → AppDelegate.handleGetURLEvent
    → URLSchemeHandler.handle(url, recorder:, presentStartPrompt:, presentStopPrompt:)
      ├─ state != .recording → NSLog, return (silent)
      └─ state == .recording → presentStopPrompt?()
            → MenuBarController.presentStopConfirmation()
                → NSAlert (modal)
                    ├─ Stop recording  → recorder.stop() → transcription
                    └─ Continue        → no-op
```

## Error handling / edge cases

- Repeated `stop` URLs while the alert is open: re-entrancy flag makes them no-ops.
- `stop` URL while transcribing: silent no-op (state is `.transcribing`, not `.recording`).
- `recorder` is nil: existing `guard let recorder` keeps the handler safe.

## Testing

- `URLSchemeHandler` is plain logic but currently couples to `NSAlert`/AppKit via closures, so the prompt itself is not unit-tested. Verification is manual:
  - `open "meetsvault://stop"` while idle → nothing happens (check console log, no notification).
  - `open "meetsvault://stop"` while recording → alert appears; "Continue recording" leaves recording running; "Stop recording" stops and transcribes.
  - `open "meetsvault://stop"` twice quickly while recording → only one alert.
- No existing unit test covers `URLSchemeHandler`; none added (the change is UI-closure wiring).

## Docs

The `stop` URL behavior is user-facing, so per `CLAUDE.md` update in the same change:

- `README.md` (URL scheme / usage section)
- `docs/USER_MANUAL.md`
- `docs/USER_MANUAL.es.md`

## Out of scope

- Headless/automatic stop without user interaction.
- Prompting on the menu-bar Stop item.
- Persisting any new setting.
