# MeetsVault User Manual

## 1. What is MeetsVault?

MeetsVault is a menu-bar app for macOS that records your meetings and turns them into text — entirely on your Mac. It captures both your microphone and the audio from the other participants (system audio), then transcribes everything locally using a Whisper AI model. No audio, no transcripts, and no personal data ever leave your computer. There is no account, no subscription, and no internet connection required once the Whisper model is downloaded.

---

## 2. Requirements

- **macOS 15 Sequoia or later**
- **Apple Silicon Mac** (M1 or later)
- **Disk space** for the Whisper model you choose (75 MB to 3 GB — see the model table in section 10)

---

## 3. Installation

1. Download `MeetsVault.zip` and unzip it. You will get `MeetsVault.app`.
2. Drag `MeetsVault.app` to your `/Applications` folder.
3. **First launch:** do not double-click the app. Instead, right-click (or Control-click) `MeetsVault.app` and choose **Open**. Click **Open** again in the dialog that appears. This one-time step is needed because the app is not signed by the Mac App Store. After the first launch you can open it normally.

---

## 4. First Launch — Onboarding Wizard

The first time you open MeetsVault, a setup wizard walks you through seven steps. You only need to do this once.

### Step 1 — Welcome

A brief introduction to the app. Click **Next** to continue.

### Step 2 — Terms & Conditions

Read the terms, check the box to confirm you accept, and click **Next**. You cannot proceed without accepting. You can reread the terms later from **Terms & Conditions** in the menu bar.

### Step 3 — Choose a Transcription Model

Pick the Whisper model that best fits your needs. The models range from small and fast to large and accurate. **small** is selected by default and is the right choice for most people.

| Model | Size | Notes |
|---|---|---|
| tiny | 75 MB | Fastest, least accurate |
| base | 142 MB | Casual use where speed matters more than accuracy |
| small | 466 MB | **Recommended** — solid accuracy at reasonable speed |
| medium | 1.5 GB | Better with accents, technical terms, or multiple languages |
| large-v3 | 3 GB | Highest accuracy; slow and needs more RAM |

You can switch models later from the menu bar (see section 10).

### Step 4 — Where to Save Recordings

Choose the folder where MeetsVault will save your transcript files and audio files. The default is `~/Meetings` (a `Meetings` folder in your home directory). Click **Choose…** to pick a different location. Click **Next** when done.

### Step 5 — Grant Permissions

MeetsVault needs two macOS permissions to record your meetings:

**Microphone**
Captures your voice. When you click **Request Permissions**, macOS will show a dialog asking for microphone access. Click **Allow**.

If the dialog does not appear or you accidentally denied it:
1. Open **System Settings**
2. Go to **Privacy & Security → Microphone**
3. Find **MeetsVault** in the list and enable it

**Screen Recording**
Used to capture the audio of the other participants on the call — their voices come through your Mac's system audio. Your screen is never recorded or saved; only the audio stream is used.

When you click **Request Permissions**, macOS will take you to System Settings. Find **MeetsVault** in the **Privacy & Security → Screen Recording** list and enable it.

> **Important:** After granting Screen Recording for the first time, you need to **quit MeetsVault and reopen it** before the permission takes effect. Without this step, the other participants' audio will be silent.

Once both permissions show a green checkmark, click **Download Model**.

### Step 6 — Model Download

MeetsVault downloads the Whisper model you selected. A progress bar shows the download status. This is the only time the app needs an internet connection. The model is cached locally and never downloaded again (unless you delete it).

If the download fails, click **Retry**. Make sure you have enough free disk space and a working internet connection.

### Step 7 — Done

Setup is complete. Click **Finish**. MeetsVault is now running in your menu bar as a waveform icon.

---

## 5. Daily Use — The Menu Bar

Click the waveform icon in the menu bar to open the MeetsVault menu.

**When idle:**
- **Start Recording** — begins recording your microphone and system audio simultaneously.

**While recording:**
- **● Recording · MM:SS** — shows elapsed time (read-only, not clickable).
- **Stop Recording** — stops the recording and immediately begins transcription.

**While transcribing:**
- **Transcribing…** — shown while the AI model processes the audio. The icon animates. You cannot start a new recording until transcription finishes.

**Always available:**
- **Open Meetings Folder** — opens your meetings folder in Finder.
- **Recent Transcripts** — a submenu listing the 5 most recently modified `.md` files in your meetings folder. Click any item to open it in your default Markdown app.
- **Language: [name]** — shows the current transcription language. Click to change it. Quick options: English, Spanish, French, German, Portuguese, Italian, Japanese, Chinese, Korean, Russian. For other languages (Arabic, Czech, Dutch, Finnish, Polish, Swedish, Turkish, and more), choose **More Languages…** for instructions on setting a language code manually.
- **Model: [name]** — shows the active Whisper model. Click **Switch Model** to open the model selector window and download a different variant.
- **Re-transcribe audio…** — opens a file picker. Select any `.wav` file and MeetsVault will transcribe it again using the current model and language. Useful after switching to a more accurate model or changing the language setting.
- **About MeetsVault** — version and build information.
- **Terms & Conditions** — reopens the terms you accepted during setup.
- **Quit MeetsVault** — exits the app.

---

## 6. Where Your Files Live

All transcripts and audio files are saved to your meetings folder (default: `~/Meetings`).

**Filename format:**

```
YYYY-MM-DD_HHMM_meeting-title.md
YYYY-MM-DD_HHMM_meeting-title.wav
```

Example:

```
2026-04-27_1430_weekly-sync.md
2026-04-27_1430_weekly-sync.wav
```

If you start a recording without providing a title (from the menu bar), the title slug will be `untitled`.

**7-day audio cleanup:** Every time MeetsVault launches, it automatically deletes `.wav` files in your meetings folder that are older than 7 days. Transcript files (`.md`) are **never** deleted automatically. If you want to keep an audio file permanently, move it out of the meetings folder before the 7 days are up.

---

## 7. Transcript File Format

Each `.md` file starts with a YAML frontmatter block followed by the transcript:

```markdown
---
title: Weekly Sync
date: 2026-04-27
started_at: 14:30:05
ended_at: 15:12:48
duration: 00:42:43
language: en
model: whisperkit-small
audio_source: system+microphone
audio_file: 2026-04-27_1430_weekly-sync.wav
---

# Weekly Sync

## Transcript

[00:00:00] Alright, let's get started.

[00:00:08] Thanks everyone for joining.
```

The `[HH:MM:SS]` timestamps mark when each segment was spoken, measured from the start of the recording.

You can open `.md` files in any Markdown editor — Obsidian, iA Writer, VS Code, or plain TextEdit all work.

---

## 8. Notifications

MeetsVault sends two kinds of system notifications:

- **Transcript ready** — appears when transcription finishes. Click the notification to open the transcript file directly.
- **Still recording reminder** — if you leave a recording running, MeetsVault sends a reminder every hour so you don't forget to stop it.

Make sure notifications are enabled for MeetsVault in **System Settings → Notifications**.

---

## 9. Automation — URL Scheme

MeetsVault responds to the `meetsvault://` URL scheme, so you can control it from scripts, Shortcuts, calendar apps, or any tool that can open a URL.

**Start a recording:**

```
meetsvault://start?title=Your+Meeting+Title
```

**Stop the current recording:**

```
meetsvault://stop
```

**From the terminal:**

```bash
open "meetsvault://start?title=Weekly+Standup"
open "meetsvault://stop"
```

**From Shortcuts.app:**
Create a shortcut with an **Open URLs** action and paste the URL above. You can then run the shortcut from the menu bar, from Spotlight, or assign it a keyboard shortcut.

**From a calendar app or webhook:**
Any tool that can open a URL can trigger a recording. Point your calendar event's "open URL on start" field at `meetsvault://start?title=Meeting+Name`.

> **Tip:** You can create a Claude Code skill that fires `meetsvault://start` when you say "start the meeting" — the URL scheme is designed exactly for this kind of automation.

---

## 10. Switching Whisper Models

You can change the Whisper model at any time from the menu bar:

1. Click the waveform icon → **Model: [name]** → **Switch Model**.
2. The model selector window opens. Choose a variant.
3. If the model is not yet downloaded, click **Download**. A progress bar tracks the download.
4. Once downloaded, the new model is used for all future recordings.

**Model trade-offs:**

| Model | Size | Speed | Accuracy |
|---|---|---|---|
| tiny | 75 MB | Very fast | Basic |
| base | 142 MB | Fast | Fair |
| small | 466 MB | Moderate | Good (default) |
| medium | 1.5 GB | Slow | Better |
| large-v3 | 3 GB | Slowest | Best |

All models run entirely on your Mac. Larger models require more RAM and take longer to transcribe, but produce fewer errors — especially with accents, technical vocabulary, or non-English speech.

Downloaded models are cached in `~/Library/Application Support/MeetsVault/models/` and do not need to be downloaded again.

---

## 11. Privacy

MeetsVault makes no network calls during recording or transcription. The only time it connects to the internet is when downloading a Whisper model for the first time (models come from Hugging Face). Once downloaded, the model lives on your Mac and is never re-fetched unless you delete it. Nothing about your meetings — not the audio, not the transcript, not the title — is ever sent to any server.

---

## 12. Troubleshooting

**The other person's voice is not in the transcript**
Screen Recording permission is not active. Open **System Settings → Privacy & Security → Screen Recording**, enable MeetsVault, then **quit and reopen** the app. This restart is required for the permission to take effect.

**My microphone is silent / only the other side is captured**
Microphone permission is not granted. Open **System Settings → Privacy & Security → Microphone** and enable MeetsVault.

**The model download failed**
Open the menu bar → **Model: [name]** → **Switch Model**, select the same model, and click **Download** again. Make sure you have enough free disk space (see the size in the model table above) and a working internet connection.

**I want to keep my `.wav` audio file**
Move the file out of your meetings folder (e.g., to your Desktop or another folder). MeetsVault only deletes `.wav` files inside the meetings folder that are older than 7 days. Files moved elsewhere are untouched.

**I lost a `.wav` file that was auto-deleted**
Once deleted, the file cannot be recovered. Going forward, move audio files you want to keep out of the meetings folder immediately after recording. Your transcript (`.md`) is always kept.
