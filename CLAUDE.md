# FnX — Claude Code Project Rules

## What this is
FnX is a **macOS menu-bar app** (Swift + AppKit + SwiftUI). It records audio while the user holds Fn, transcribes via OpenAI Whisper, optionally rewrites via GPT-4o-mini, and types the result into the focused app via CGEvent.

**Not** a monorepo. No `app/` + `web/` split. No Supabase. No Next.js.
The global FractalX rules about Supabase/web/Edge Functions do NOT apply here — ignore them.

## Repo layout
```
Package.swift              SPM manifest (macOS 13+, two targets: FnXUI lib + FnX executable)
build.sh                   Builds release binary + assembles FnX.app
release.sh                 Signs + notarizes + zips for distribution
Info.plist                 Bundle id com.fnx.app, LSUIElement (menu-bar only)
.github/workflows/         CI: auto-tag, build, sign, notarize, publish, update Homebrew tap
Sources/FnX/
├── App/                   Entry point + AppDelegate (executable target only)
├── Services/              Audio, Whisper, GPT, Keyboard, License, StatusBar, Sound
├── Windows/               NSWindowController wrappers (Overlay, Settings, License, Onboarding)
├── Views/                 SwiftUI views
├── ViewModels/            @Observable view models
├── Helpers/               Keychain, Secrets (runtime API key resolver)
└── Resources/             Icons (copied as SPM resources)
docs/
├── ARCHITECTURE.md        Full control flow + file map
├── DEVELOPMENT.md         Local setup, configure OpenAI key, change models, debug
└── RELEASE.md             Signing, notarization, GitHub Actions, Homebrew tap
```

## Critical config
- **OpenAI API key**: resolved at runtime in `Secrets.openAIAPIKey` — env var → Keychain → `Secrets+Local.swift` (gitignored). **Never** commit a real key to `Secrets.swift`.
- **Transcription model**: `whisper-1` in `Services/WhisperService.swift:37`
- **Text-processing model**: `gpt-4o-mini` in `Services/TextProcessor.swift:15`
- **License backend**: LemonSqueezy (endpoints in `Services/LicenseManager.swift`)
- **Update channel**: GitHub releases at `admin-fractalx/fnx-mac`

## Conventions
- MVVM with `@Observable` view models, async/await throughout.
- Service ownership: `AppDelegate` initializes all singletons and wires callbacks.
- No force unwraps in new code. No magic numbers — pull into named constants.
- SwiftUI views in `Views/`, AppKit window controllers in `Windows/`.
- File naming:
  - Views: `[Name]View.swift`
  - View models: `[Name]ViewModel.swift`
  - Window controllers: `[Name]Window.swift`
  - Services: noun (`AudioRecorder.swift`, not `AudioRecorderService.swift`)

## Session checklist
1. Read `tasks/lessons.md` for past corrections.
2. Check `tasks/todo.md` for open items.
3. Before touching `Secrets*`, `KeychainHelper`, or anything that ships a binary — re-read `docs/DEVELOPMENT.md` to confirm the key-loading contract.

## Documentation policy
Touch the corresponding doc when you change related code:

| You changed | Update |
|-------------|--------|
| AI model name, endpoint, or prompt | `docs/ARCHITECTURE.md` + `docs/DEVELOPMENT.md` (model section) |
| Build/signing/notarization | `docs/RELEASE.md` |
| Architecture (new service, control flow) | `docs/ARCHITECTURE.md` |
| Local setup flow (Secrets, permissions, env vars) | `docs/DEVELOPMENT.md` |
| Bundle id, entitlement, Info.plist key | `docs/RELEASE.md` |
