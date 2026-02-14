# FnX

Voice-to-text for macOS: hold **Fn** to record, release to transcribe and type into any focused app.

## Features

- **Fn key trigger** — Hold Fn to record, release to stop; transcription is typed at the cursor
- **Menu bar app** — No dock icon; run from the menu bar and open Settings or Quit from there
- **OpenAI Whisper** — Uses the Whisper API for transcription
- **Text rules** — Optional find/replace rules applied before text is inserted

## Requirements

- macOS 13 or later
- [OpenAI API key](https://platform.openai.com/api-keys) (stored in Keychain)

## Installation

### Homebrew

```bash
brew tap YOUR_USER/fnx
brew install --cask fnx
```

Replace `YOUR_USER` with the GitHub user or org that hosts the [Homebrew tap](https://github.com/YOUR_USER/homebrew-fnx).

### Manual

Download `FnX-x.x.zip` from [Releases](https://github.com/YOUR_USER/fnx/releases), unzip, and move `FnX.app` to Applications.

## Usage

1. Launch FnX. On first run, complete onboarding and grant:
   - **Microphone** — for recording
   - **Accessibility** — to type into other apps
   - **Input Monitoring** — to detect the Fn key
2. Enter your OpenAI API key when prompted (saved in Keychain).
3. Focus any text field, hold **Fn** to record, release to transcribe and insert.

## Building from source

```bash
git clone https://github.com/YOUR_USER/fnx.git
cd fnx
./build.sh
open FnX.app
```

**Release build (signed):**

```bash
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
./release.sh 1.0
```

See `release.sh` for optional notarization with `NOTARIZE=1` and `NOTARY_KEYCHAIN_PROFILE`.

## License

[Add your license here.]
