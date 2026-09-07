# Design: `meetsvault://status_report` → ntfy push to phone

Date: 2026-09-07

## Problem

Today there is no way to find out whether MeetsVault is recording without
looking at the Mac. The state exists (`AudioRecorder.state`, values `idle` /
`recording` / `transcribing`) but it is only surfaced visually and only in-process:

- the menu-bar icon (`record.circle.fill`, tinted red) while recording,
- an `● Recording · MM:SS` item in the dropdown,
- an hourly "Recording still in progress" local notification.

Nothing is queryable from outside the process. The concrete failure this
addresses: walking away from the Mac with a recording still running and having
no way to check from the phone.

## Desired behavior

A new URL command, `meetsvault://status_report`:

- `recorder.state == .recording` → POST a message to a configured ntfy topic,
  which the user's iPhone is subscribed to.
- any other state (`.idle`, `.transcribing`) → **fully silent**: `NSLog` only.
- no ntfy topic configured → **fully silent**, even while recording.

The command never opens a window, never changes recorder state, and never
blocks. **Silence on the phone means "not recording"** — that is the designed
signal, not a failure mode.

`.transcribing` deliberately counts as "not recording": the microphone is
already closed by then, so there is nothing the user needs to act on.

The topic is configured from the menu-bar dropdown (see below), not from a
config file, so nothing secret is ever committed to this public repo.

## Components & changes

### `Settings` (`MeetsVault/MeetsVault/Settings/Settings.swift`)

Two new keys in `Key`, following the existing accessor style:

- `ntfyTopic` — `String?`, no default. `nil` or empty means the feature is off.
- `ntfyServerURL` — `String`, default `"https://ntfy.sh"`. No UI; changeable
  with `defaults write` only, for a possible self-hosted server later.

```swift
var ntfyTopic: String? {
    get {
        guard let t = defaults.string(forKey: Key.ntfyTopic), !t.isEmpty else { return nil }
        return t
    }
    set { defaults.set(newValue, forKey: Key.ntfyTopic) }
}
```

Topic validation lives here as a static pure function so it is unit-testable
independently of any UI:

- trim surrounding whitespace,
- empty after trimming is not an error: it means "clear the setting" and turns
  the feature off,
- reject anything containing whitespace or `/`,
- otherwise accept.

ntfy topics are alphanumerics plus `-` and `_`; a `/` would silently change the
request path, which is the failure worth guarding against.

### `NtfyClient` (new — `MeetsVault/MeetsVault/Notifications/NtfyClient.swift`)

A small type with one job: turn a message into a POST to ntfy.

- `init(serverURL: String, topic: String, session: URLSession = .shared)` — the
  server and topic are passed in rather than read from `Settings` inside the
  client, and the session is injected so tests can substitute a `URLProtocol`
  stub. The caller (`URLSchemeHandler`) is what touches `Settings`, so the
  client has no global dependencies and is testable in isolation.
- `send(title:body:tags:)` — builds `POST {server}/{topic}` with the body as
  plain text and `Title` / `Tags` headers, per the ntfy publishing API.
- Request timeout ~10s.
- Fire-and-forget: the completion handler logs and discards. Nothing it does can
  throw into, block, or otherwise disturb a recording.
- **Logging must never include the topic.** Log host and status code only —
  under the no-auth model the topic name *is* the credential, and this repo is
  public. An untracked `logs/` directory already exists in the working tree.

### `AudioRecorder` (`MeetsVault/MeetsVault/Recording/AudioRecorder.swift`)

`sessionTitle` and `sessionStartDate` change from `private` to `private(set)`
so the handler can build a useful message. No change to the state machine, the
capture path, or the delegate protocol.

### `URLSchemeHandler` (`MeetsVault/MeetsVault/URLScheme/URLSchemeHandler.swift`)

New `case "status_report"` in the existing `switch url.host`, in the same shape
as the `start` and `stop` cases: guard on state, silent `NSLog` return when it
does not apply.

Verified on this toolchain that `URL(string: "meetsvault://status_report")?.host`
returns `"status_report"` — the underscore is not a valid hostname character per
RFC, but Foundation's parser accepts it, so the existing `url.host` switch needs
no structural change.

Unlike `start` and `stop`, this case needs no prompt closure: it presents no UI.
It reads the recorder and calls `NtfyClient` directly.

### `MenuBarController` (`MeetsVault/MeetsVault/MenuBar/MenuBarController.swift`)

A new **"Phone Notifications"** submenu in `buildMenu()`, alongside the existing
Language and Model submenus:

- a disabled status line: `Topic: <topic>` or `Topic: not set`,
- **"Set ntfy Topic…"** → `NSAlert` with an `NSTextField` accessory view,
  prefilled with the current topic, Save / Cancel.

An `NSAlert` rather than a new `NSWindowController`: it is a single text field,
and a window on the scale of `CaptureSourceWindow` is disproportionate for that.

- `NSApp.activate(ignoringOtherApps: true)` before showing, since the app runs
  as an `LSUIElement` agent.
- Save with a valid topic → persist and rebuild the menu.
- Save with an empty field → clear the setting (feature off).
- Save with an invalid topic → show why; do not persist.

The topic is shown in plain text in the menu. It is the credential, but it is
displayed only on the user's own machine, and being able to verify what is
configured is worth more here than hiding it.

## Data flow

```
open "meetsvault://status_report"
  → AppDelegate.handleGetURLEvent
    → URLSchemeHandler.handle(url, recorder:, presentStartPrompt:, presentStopPrompt:)
      ├─ state != .recording        → NSLog, return (silent)
      ├─ Settings.ntfyTopic == nil  → NSLog, return (silent)
      └─ state == .recording        → NtfyClient.send(...)
            → POST https://ntfy.sh/<topic>
                → iPhone subscribed to <topic> gets the push
```

Message contents:

- Title: `🔴 Recording in progress`
- Body: `<session title> · HH:MM:SS elapsed`, elapsed computed from
  `sessionStartDate`
- Tags: `red_circle`
- No custom `Priority`

## Error handling / edge cases

All failures are silent to the user and visible in the log. None may affect an
active recording.

- No topic configured → silent no-op.
- Malformed server URL or topic that fails to percent-encode → log, no request.
- Network failure, DNS failure, timeout, non-2xx from ntfy → log host and status
  code, discard.
- `recorder` is nil → the existing `guard let recorder` already covers it.
- Repeated `status_report` URLs → each fires its own request; no
  re-entrancy guard needed, since nothing modal or stateful is involved.
- No session title (recording started without one) → fall back to a generic
  body without the title.

## Testing

Unit tests (`MeetsVaultTests/`):

- `NtfyClientTests` — with an injected `URLSession` backed by a `URLProtocol`
  stub: asserts the request URL (`{server}/{topic}`), HTTP method, `Title` and
  `Tags` headers, and plain-text body.
- Elapsed-duration formatting → `HH:MM:SS`.
- Topic validation: accepts a normal topic, trims whitespace, rejects a topic
  containing `/`, rejects one containing a space, treats empty as "clear".
- The new `Settings` keys extend the existing `MeetsVaultTests/SettingsTests.swift`.

Tests use an invented topic (e.g. `test-topic`). No real topic in any fixture.

Manual verification:

- `open "meetsvault://status_report"` while idle → nothing on the phone, log line only.
- while recording, topic set → push arrives with title and elapsed time.
- while recording, topic not set → nothing, log line only.
- while transcribing → nothing.

The `URLSchemeHandler` case itself is not unit-tested, consistent with the
existing `start` / `stop` cases.

## Public-repo constraints

This repo is public, and with an unauthenticated ntfy topic the topic name is
the only thing protecting the channel. Therefore:

- The topic lives in `UserDefaults`
  (`~/Library/Preferences/com.germanpereyra.meetsvault.plist`), outside the repo.
  No versioned config file, no hardcoded default in Swift.
- Docs use `<your-topic>` as a placeholder and never a real topic.
- `NtfyClient` logs host and status code, never the full URL.
- Tests use an invented topic.

## Docs

User-facing, so per `CLAUDE.md` all three are updated in the same commit:

- `README.md` — Features and Usage: the `status_report` command and the new menu item.
- `docs/USER_MANUAL.md`
- `docs/USER_MANUAL.es.md`

Additionally, the "no cloud, no network calls" claim in `README.md` and
`CLAUDE.md` becomes inaccurate and must be corrected to something like: no
network calls during recording or transcription; the only outbound call is
optional, off by default, and fires only when an ntfy topic is configured and a
`status_report` is requested.

## Out of scope

- Automatic event pushes (recording started / stopped / transcript ready).
- The app subscribing to or listening on ntfy.
- Bearer-token auth, protected topics, self-hosted ntfy UI.
- Keychain storage.
- A Settings window; the server URL stays `defaults write`-only.
