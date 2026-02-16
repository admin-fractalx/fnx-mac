# FnX

**Your voice, everywhere.** A lightweight macOS menu bar app that turns speech into text in any application. Hold **Fn** to record, release to transcribe — the text is typed directly into whatever you're working on.

<p align="center">
  <strong>Hold Fn</strong> &rarr; Speak &rarr; <strong>Release Fn</strong> &rarr; Text appears at your cursor
</p>

## Features

### Core
- **Fn key trigger** — Hold to record, release to transcribe. Works globally in any app.
- **Local Whisper model** — Transcription runs entirely on-device using [whisper.cpp](https://github.com/ggerganov/whisper.cpp). No audio leaves your machine.
- **Dynamic Island overlay** — A notch-style expanding indicator shows recording, processing, and done states with smooth animations.
- **Audio feedback** — Subtle ascending/descending tones confirm when recording starts and stops.
- **Menu bar app** — Lives in the status bar. No dock icon, no distractions.

### Smart Rules
Built-in text transformation rules that process your transcription before typing:

| Rule | What it does |
|------|-------------|
| **Translate to English** | Offline translation via Whisper — supports 90+ languages, no internet needed |
| **Clean English** | Cleans up dictation and outputs polished English (fixes grammar, removes filler words) |
| **Clean Spanish** | Same cleanup, outputs polished Spanish |
| **Prompt Builder** | Turns spoken ideas into well-structured AI prompts |
| **Professional Email** | Converts rambling thoughts into a concise, formatted email |

Rules handle messy input gracefully — mishearings, filler words (um, uh, like, este), repetitions, false starts, and mixed-language fragments are all cleaned up automatically.

You can also create **custom rules** with your own AI prompts.

### Intelligent Filtering
FnX detects when audio quality is too poor and silently discards the result instead of typing garbage. Filters out Whisper hallucinations like `[BLANK_AUDIO]`, `(silence)`, repeated characters, and other junk patterns.

### Licensing
- **Free** — 15 transcriptions per day (all rules included)
- **Pro** — Unlimited transcriptions. Activate with a license key from [FractalX](https://fractalx.lemonsqueezy.com).

## Requirements

- macOS 13+
- MacBook with Apple Silicon or Intel (Whisper model runs locally)

## Permissions

FnX needs three system permissions to work. You'll be guided through granting them during onboarding:

| Permission | Why |
|-----------|-----|
| **Microphone** | To record your voice |
| **Accessibility** | To type text into other applications |
| **Input Monitoring** | To detect when you press the Fn key |

Grant these in **System Settings → Privacy & Security**.

## Installation

### Manual

Download `FnX-x.x.zip` from [Releases](https://github.com/nicklama/fnx/releases), unzip, and move `FnX.app` to `/Applications`.

### From Source

```bash
git clone https://github.com/nicklama/fnx.git
cd fnx
./build.sh
open FnX.app
```

## Usage

1. **Launch FnX** — Complete onboarding and grant permissions on first run.
2. **Focus any text field** — Click into a text input in any app.
3. **Hold Fn** — The notch indicator shows "Listening..." with a red pulse.
4. **Speak** — Talk naturally in any language.
5. **Release Fn** — The indicator transitions to "Processing...", then "Done!".
6. **Text appears** — Transcribed (and optionally transformed) text is typed at your cursor.

### Selecting a Rule

Click the FnX icon in the menu bar to:
- See your remaining free transcriptions
- Select an active rule (or disable rules for raw transcription)
- Open Settings to manage rules
- Open License to upgrade or manage your subscription

### Custom Rules

Open **Settings** from the menu bar → click **New Rule**:
- Give it a name
- Toggle **offline Whisper translation** for language translation without AI
- Or write a custom **AI prompt** that transforms the transcribed text

## Architecture

```
Sources/FnX/
├── App/
│   ├── main.swift                # Entry point
│   └── AppDelegate.swift         # Lifecycle orchestration
├── Services/
│   ├── KeyboardMonitor.swift     # Global Fn key detection
│   ├── AudioRecorder.swift       # AVAudioEngine recording (16kHz PCM)
│   ├── WhisperService.swift      # Local whisper.cpp inference
│   ├── TextProcessor.swift       # GPT-4o-mini for AI rules
│   ├── TextInjector.swift        # CGEvent keyboard simulation
│   ├── RulesManager.swift        # Rule storage & defaults
│   ├── LicenseManager.swift      # LemonSqueezy integration
│   ├── StatusBarManager.swift    # Menu bar UI
│   └── SoundEffect.swift         # Programmatic audio tones
├── Windows/
│   ├── OnboardingWindow.swift    # First-run setup (5 steps)
│   ├── SettingsWindow.swift      # Rule management
│   ├── LicenseWindow.swift       # License activation
│   └── OverlayWindow.swift       # Notch-style status overlay
├── Views/                        # SwiftUI views
├── ViewModels/                   # MVVM view models
├── Helpers/
│   ├── KeychainHelper.swift      # Secure storage
│   └── Secrets.swift             # API configuration
└── Resources/
    └── ggml-base.bin             # Bundled Whisper model (~148MB)
```

### How It Works

```
Fn pressed → AudioRecorder starts → WAV file captured at 16kHz
                                          │
Fn released → WhisperService transcribes locally
                                          │
              RulesManager checks active rule
              ├── No rule → raw text
              ├── Translate → Whisper with translate=true
              └── AI rule → GPT-4o-mini processes text
                                          │
              Hallucination filter validates output
                                          │
              TextInjector types into focused app via CGEvent
```

## Release Build

```bash
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
./release.sh 1.0
```

For notarization:

```bash
NOTARIZE=1 NOTARY_KEYCHAIN_PROFILE="your-profile" ./release.sh 1.0
```

## Tech Stack

- **Swift 5.9+** / **SwiftUI** + **AppKit**
- **[SwiftWhisper](https://github.com/exPHAT/SwiftWhisper)** — whisper.cpp Swift bindings
- **AVAudioEngine** — Real-time audio capture
- **CGEvent** (Carbon) — Low-level keyboard simulation
- **LemonSqueezy** — License validation & payments

## License

MIT License — see [LICENSE](LICENSE) for details.

---

Built by [Fractal X](https://fractalx.com)
