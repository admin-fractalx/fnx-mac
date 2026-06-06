# Architecture — FnX

## Overview
FnX is a macOS menu-bar app that turns speech into typed text. The user holds the **Fn** key to record, releases to transcribe via the OpenAI Whisper API, and the resulting text is typed into the currently focused app via `CGEvent`. An optional *rule* can post-process the raw transcription through GPT-4o-mini (cleanup, translate, reformat, etc.) before injection.

The app has no dock icon (`LSUIElement = true`) — its entire UI surface is a status-bar menu, an always-on-top overlay HUD, and a few NSWindow-based panels (Settings, License, Onboarding).

## Tech stack
- **Swift 5.9 / macOS 13+**
- **SwiftUI** for view bodies, **AppKit** for windows + menu bar + global event monitoring
- **AVFoundation** (AVAudioEngine) for 16 kHz mono PCM capture
- **CoreGraphics / Carbon** for keystroke injection
- **Security framework** for Keychain (API key + license key)
- **OpenAI** Whisper + Chat Completions APIs
- **LemonSqueezy** for license activation/validation

## Package structure
Two SPM targets:
- **`FnXUI`** (library) — every file under `Sources/FnX/` except `Sources/FnX/App/`
- **`FnX`** (executable) — `Sources/FnX/App/{main.swift, AppDelegate.swift}`, depends on `FnXUI`

The split exists so that `App/` (binary entry point) can stay tiny and lean on the library for everything else.

## Control flow: Fn pressed → text typed
```
User presses Fn
   ↓
KeyboardMonitor.onRecordingStarted               (NSEvent global monitor on .flagsChanged)
   ↓
AppDelegate.startRecording()
   ├── Secrets.openAIAPIKey empty? — if true, show "No API key" overlay, bail (mic never opens)
   ├── LicenseManager.canTranscribe? — if false, show "limit" overlay + open paywall, bail
   ├── SoundEffect.playStartTone()
   ├── StatusBarManager.setRecording(true)
   ├── OverlayWindow.showRecording()             (red pulse on always-on-top HUD)
   └── AudioRecorder.startRecording()            (writes 16 kHz mono WAV to /tmp)

User speaks, releases Fn
   ↓
KeyboardMonitor.onRecordingStopped
   ↓
AppDelegate.stopRecording()
   ├── AudioRecorder.stopRecording()
   ├── SoundEffect.playStopTone()
   ├── OverlayWindow.showProcessing()
   └── Task {
           switch RulesManager.activeRule {
           case rule.useTranslation == true:
               WhisperService.transcribe(_, translate: true)   → /v1/audio/translations
           case rule.prompt != "":
               raw = WhisperService.transcribe(_)              → /v1/audio/transcriptions
               TextProcessor.process(raw, rulePrompt, apiKey)  → /v1/chat/completions (gpt-4o-mini)
           default:
               WhisperService.transcribe(_)                    → /v1/audio/transcriptions
           }
           guard AppDelegate.isUsableTranscription(text) else { hide; return }
           TextInjector.type(text)                              (CGEvent keystrokes into focused app)
           OverlayWindow.showDone()
           LicenseManager.incrementUsage()
           StatusBarManager.setupMenu()                         (refresh "X/15 left")
       }
```

## File map

### `App/` (executable target)
| File | Responsibility |
|------|---------------|
| `main.swift` | Creates `NSApplication`, sets `.accessory` activation policy, installs `AppDelegate` |
| `AppDelegate.swift` | Wires every service, owns the Fn → record → transcribe → inject pipeline, hosts onboarding/update/settings windows, ships the `isUsableTranscription` hallucination filter |

### `Services/`
| File | Responsibility |
|------|---------------|
| `KeyboardMonitor.swift` | Global `NSEvent.flagsChanged` watcher; fires recording start/stop callbacks |
| `AudioRecorder.swift` | `AVAudioEngine` tap → 16 kHz mono WAV at `/tmp/fnx_recording_<UUID>.wav` |
| `WhisperService.swift` | POSTs WAV multipart to `/v1/audio/transcriptions` or `/translations` (model: `whisper-1`) |
| `TextProcessor.swift` | POSTs `{system: rulePrompt, user: rawText}` to `/v1/chat/completions` (model: `gpt-4o-mini`, temp 0.3) |
| `TextInjector.swift` | Sends Unicode strings as `CGEvent` keyDown/keyUp into the focused app |
| `RulesManager.swift` | `UserDefaults`-backed rule list + active-rule selection; ships 5 default rules, schema version 7 |
| `LicenseManager.swift` | Free (15/day) vs Pro (unlimited), LemonSqueezy activate/validate/deactivate, Keychain-backed license key |
| `StatusBarManager.swift` | `NSStatusBar` item + dropdown menu (rules, license, settings, update, quit); icon swap during recording |
| `SoundEffect.swift` | Programmatic AVAudioEngine sine tones for start/stop/done |

### `Windows/`
| File | Responsibility |
|------|---------------|
| `OverlayWindow.swift` | Borderless click-through HUD at top of screen, level `CGShieldingWindowLevel() + 1`, shows recording/processing/done/limit states |
| `SettingsWindow.swift` | Rules CRUD window (560×390) |
| `LicenseWindow.swift` | License activation + plan info (480×560) |
| `OnboardingWindow.swift` | First-run modal (5 pages: welcome, how-it-works, smart rules, permissions, try-it) |

### `Views/` (SwiftUI)
| File | Responsibility |
|------|---------------|
| `OverlayView.swift` | Animated pill HUD (red pulse / cyan spinner / green check / paywall states) |
| `SettingsView.swift` | Searchable rule list + prompt editor |
| `LicenseView.swift` | Free-tier usage bar + Pro activation flow + pricing cards |
| `OnboardingView.swift` | 5-page onboarding carousel with permission gating + live transcription demo |

### `ViewModels/` (Observable)
| File | Drives |
|------|-------|
| `OverlayViewModel.swift` | HUD state machine (recording / processing / done / limit / pro-required / hidden) |
| `SettingsViewModel.swift` | Rules selection + edit form state |
| `LicenseViewModel.swift` | Tier display, activation, LemonSqueezy checkout URLs |
| `OnboardingViewModel.swift` | Page index, permission status, try-it demo |

### `Helpers/`
| File | Responsibility |
|------|---------------|
| `Secrets.swift` | Runtime resolver for `openAIAPIKey`: env var → Keychain → `Secrets+Local.swift` |
| `Secrets+Local.swift` | **Gitignored.** Holds `localFallbackAPIKey` for local dev (or injected by CI). See `Secrets+Local.swift.example` |
| `KeychainHelper.swift` | Generic-password CRUD for the OpenAI key (`com.fnx.openai-api-key`) |

## External endpoints and models
| Service | Endpoint | Model | Called from |
|---------|----------|-------|-------------|
| Whisper (transcribe) | `https://api.openai.com/v1/audio/transcriptions` | `whisper-1` | `WhisperService.swift:11,37` |
| Whisper (translate) | `https://api.openai.com/v1/audio/translations` | `whisper-1` | `WhisperService.swift:10,37` |
| GPT (rules) | `https://api.openai.com/v1/chat/completions` | `gpt-4o-mini` | `TextProcessor.swift:4,15` |
| LemonSqueezy activate | `https://api.lemonsqueezy.com/v1/licenses/activate` | — | `LicenseManager.swift:92` |
| LemonSqueezy validate | `https://api.lemonsqueezy.com/v1/licenses/validate` | — | `LicenseManager.swift:126` |
| LemonSqueezy deactivate | `https://api.lemonsqueezy.com/v1/licenses/deactivate` | — | `LicenseManager.swift:108` |
| GitHub releases | `https://api.github.com/repos/admin-fractalx/fnx-mac/releases/latest` | — | `AppDelegate.swift:250` |

LemonSqueezy checkout URLs live in `ViewModels/LicenseViewModel.swift:15-16`.

## Persistent state

### UserDefaults
| Key | Type | Purpose |
|-----|------|---------|
| `fnx_onboarding_completed` | Bool | Skip onboarding after first successful run |
| `fnx_rules` | JSON-encoded `[Rule]` | All rules (defaults + custom) |
| `fnx_active_rule_id` | String (UUID) | Currently selected rule |
| `fnx_rules_version` | Int | Schema version (current: 7); bump triggers default-rule reload |
| `fnx_license_tier` | String | `"free"` or `"pro"` |
| `fnx_usage_date` | String (YYYY-MM-DD) | Day the counter belongs to |
| `fnx_usage_count` | Int | Transcriptions used today (free tier only) |
| `fnx_machine_id` | String (UUID) | Stable instance ID for LemonSqueezy `instance_name` |

### Keychain
| Service | Account | Holds |
|---------|---------|-------|
| `com.fnx.openai-api-key` | `api-key` | OpenAI API key (optional override; see `Secrets`) |
| `com.fnx.license-key` | `license` | LemonSqueezy license key |

## Licensing model
- **Free**: 15 transcriptions/day, AI rules blocked (translate rule still allowed because Whisper handles it).
- **Pro**: unlimited transcriptions, all rules allowed.
- Daily counter resets when `fnx_usage_date` ≠ today.
- `LicenseManager.validateOnStartup()` re-checks the saved license against LemonSqueezy each launch; revoked keys silently downgrade to free.

## OS integration
- **Bundle id**: `com.fnx.app`
- **Minimum macOS**: 13.0 (Ventura)
- **`LSUIElement = true`** — no dock icon
- **Required permissions** (declared in `Info.plist`, prompted in onboarding):
  - Microphone (`NSMicrophoneUsageDescription`)
  - Accessibility (`NSAppleEventsUsageDescription`) — needed for both Fn key detection and text injection
  - Input Monitoring — required for `NSEvent` global monitoring of modifier keys
- **Onboarding** flips activation policy from `.regular` (so the modal can take focus) to `.accessory` (menu-bar only) once complete.

## Hallucination filter
`AppDelegate.isUsableTranscription(_:)` (lines 197–243) drops Whisper outputs that match known junk patterns: `[BLANK_AUDIO]`, `(silence)`, "thanks for watching", single repeated characters, very short bracketed strings, etc. Dropped transcriptions never type anything and don't count against the daily limit.

## Build & release pipeline
- `build.sh` — debug/local: `swift build -c release` + assemble `FnX.app` with `Info.plist`, `AppIcon.icns`, and SPM resource bundles copied next to the binary.
- `release.sh` — wraps `build.sh` with codesign + optional notarization, ditto-zips for upload.
- `.github/workflows/release.yml` — on every push to `main`: auto-bump patch version, inject `OPENAI_API_KEY` into `Secrets+Local.swift`, build, sign, notarize, publish GitHub Release, push updated Cask to the `admin-fractalx/homebrew-tap` repo.

See [`RELEASE.md`](RELEASE.md) for the full release flow.
