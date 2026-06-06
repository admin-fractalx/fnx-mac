# Development — FnX

Setup guide for working on FnX locally. If you only want to *use* the app, see the [README](../README.md).

## Requirements

- macOS 13 (Ventura) or newer
- Xcode 15+ (Swift 5.9 toolchain)
- An OpenAI API key with access to `whisper-1` and `gpt-4o-mini` — create one at https://platform.openai.com/api-keys

> **Heads-up about an older leaked key.** Earlier revisions of this repo committed a real API key to `Sources/FnX/Helpers/Secrets.swift`. If you cloned before that file was scrubbed from history, **assume the key is compromised** — Bryan is rotating it. Don't reuse it.

## First-time setup

```bash
git clone https://github.com/admin-fractalx/fnx-mac.git
cd fnx-mac
```

The repo never ships a real API key. Pick **one** of the three configuration methods below before your first build.

### Method 1 — Local file (recommended for daily dev)

Copy the template and paste your key:

```bash
cp Sources/FnX/Helpers/Secrets+Local.swift.example \
   Sources/FnX/Helpers/Secrets+Local.swift
$EDITOR Sources/FnX/Helpers/Secrets+Local.swift
# Set `localFallbackAPIKey = "sk-..."`
```

`Secrets+Local.swift` is gitignored. It won't be committed.

### Method 2 — macOS Keychain

Save the key once into the system Keychain:

```bash
security add-generic-password \
  -s "com.fnx.openai-api-key" \
  -a "api-key" \
  -w "sk-your-key-here" \
  -U
```

Now any build of FnX on this machine will pick it up at runtime. To rotate, run the same command with the new key.

### Method 3 — Environment variable

For ad-hoc runs from the terminal:

```bash
export OPENAI_API_KEY="sk-..."
swift run FnX
```

Note: launching `FnX.app` from Finder won't see your shell env. Use Method 1 or 2 for `.app` workflows.

### Resolution order

`Secrets.openAIAPIKey` checks each source in order and uses the first non-empty value:

1. `OPENAI_API_KEY` env var
2. Keychain (`com.fnx.openai-api-key` / `api-key`)
3. `Secrets+Local.swift` (`localFallbackAPIKey`)

The compiled binary always falls back to whatever is in `Secrets+Local.swift` at build time, so release builds inject the production key there (via CI — see [`RELEASE.md`](RELEASE.md)).

### What happens with no key configured

If all three sources are empty, the app launches normally but the **first time the user holds Fn**, it shows a "No OpenAI API key" overlay (red key-slash icon, subtitle *"Configure it in Settings"*) and refuses to record. The mic never opens, no audio is captured, no API call is made. This check happens in `AppDelegate.startRecording()` before the recorder is touched.

## Build & run

### From the terminal

```bash
./build.sh         # builds FnX.app at repo root
open FnX.app
```

`build.sh` auto-creates an empty `Secrets+Local.swift` if it doesn't exist, so the first build never breaks — but the app will hit a 401 from OpenAI until you configure a real key.

### From Xcode

```bash
open Package.swift
```

In the scheme picker pick **FnX** (the executable, not `FnXUI`), target **My Mac**, then ⌘R.

> ⚠️ Xcode runs the binary out of `~/Library/Developer/Xcode/DerivedData/...`. The macOS Accessibility permission you granted to `FnX.app` does **not** transfer — you'll be prompted again, and `tccutil reset Accessibility com.fnx.app` is sometimes needed to re-prompt cleanly.

## Permissions

FnX needs three system permissions. Onboarding walks the user through them, but for development you can grant them up-front in **System Settings → Privacy & Security**:

| Permission | Reason |
|------------|--------|
| Microphone | Capture audio for Whisper |
| Accessibility | Type text into other apps (CGEvent) |
| Input Monitoring | Detect the global Fn key press |

If a permission was denied, reset it with `tccutil reset <Service> com.fnx.app` (e.g. `tccutil reset Microphone com.fnx.app`) and re-launch.

## Changing the AI models

| What to change | Where |
|----------------|-------|
| Transcription model (`whisper-1`) | `Sources/FnX/Services/WhisperService.swift:37` |
| Text-processing model (`gpt-4o-mini`) | `Sources/FnX/Services/TextProcessor.swift:15` |
| Temperature for text rules (0.3) | `Sources/FnX/Services/TextProcessor.swift:20` |
| Endpoints (OpenAI host) | `WhisperService.swift:10-11`, `TextProcessor.swift:4` |

If you swap in a model that uses a different schema (e.g. a Responses-style endpoint, or Anthropic), you'll need to refactor `TextProcessor.process(...)` — it currently assumes OpenAI Chat Completions.

## Built-in rules

The 5 default rules ship in `Sources/FnX/Services/RulesManager.swift:91-183`. Each one is either:
- **Translate** (`useTranslation: true`) — Whisper's `/translations` endpoint
- **Prompt-driven** (`useTranslation: false`, non-empty `prompt`) — Whisper transcribes, then GPT rewrites with `prompt` as the system message

If you change a default rule's contents, also bump `currentVersion` in `RulesManager.swift:30` so existing users get the update on next launch.

## Debugging tips

- **`print()` shows up in Console.app** under process `FnX`. Filter by `subsystem com.fnx.app` (not currently wired — switch to `os_log` if you want category filtering).
- **Reset onboarding** to test the first-run flow:
  ```bash
  defaults delete com.fnx.app fnx_onboarding_completed
  ```
  `build.sh` does this automatically unless `BUILD_FOR_RELEASE=1` is set.
- **Reset license to free**:
  ```bash
  defaults delete com.fnx.app fnx_license_tier
  defaults delete com.fnx.app fnx_usage_count
  defaults delete com.fnx.app fnx_usage_date
  ```
- **Reset rules to defaults**:
  ```bash
  defaults delete com.fnx.app fnx_rules
  defaults delete com.fnx.app fnx_rules_version
  ```
- **Inspect Keychain entries**:
  ```bash
  security find-generic-password -s "com.fnx.openai-api-key"
  security find-generic-password -s "com.fnx.license-key"
  ```

## Common gotchas

- **App keeps asking for Accessibility every launch** — macOS sometimes loses the entitlement for unsigned dev builds. Sign locally with an ad-hoc identity (`codesign --force --sign - FnX.app`) to make the grant stick.
- **Whisper returns garbage / 401** — your key isn't being picked up. Check resolution order above; `print(Secrets.openAIAPIKey.prefix(7))` from `applicationDidFinishLaunching` to confirm.
- **Fn key doesn't trigger anything** — Input Monitoring permission missing, or another app (Karabiner-Elements, AltTab) is consuming the event first.
- **`Cannot find 'localFallbackAPIKey' in scope`** — `Secrets+Local.swift` was deleted. Re-run `./build.sh` (creates a stub) or copy from the `.example`.

## Project layout reference

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the full file-by-file map and control flow.
