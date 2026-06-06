# Todo — FnX

Active engineering tasks. Check off as you go; archive completed sections into a dated section below.

## In progress
- [ ] (none)

## Backlog

### Security (do before sharing the repo)
- [ ] **Rotate the OpenAI API key** that was committed to `Sources/FnX/Helpers/Secrets.swift` (commit `c0d83c4` and onward). Revoke at https://platform.openai.com/api-keys.
- [ ] **Scrub the leaked key from git history**:
  ```bash
  brew install git-filter-repo
  git filter-repo --path Sources/FnX/Helpers/Secrets.swift --invert-paths
  # Re-add the new (safe) Secrets.swift, commit, force-push.
  ```
  Notify anyone with a clone to re-clone or rebase.
- [ ] Audit GitHub repo settings: enable secret scanning + push protection.

### Polish (post-share)
- [ ] Settings UI so users can enter their own OpenAI key (writes to Keychain via `KeychainHelper.saveAPIKey`). Removes the need for production-baked keys for power users.
- [ ] Switch `print()` calls in `AppDelegate` to `os_log` with a subsystem for Console.app filtering.
- [ ] Move the GitHub repo coords (`admin-fractalx/fnx-mac`) into a single constant — currently duplicated in `AppDelegate.swift:250` and `release.yml`.

## Completed

### 2026-06-06 — Onboarding for a new contributor
- [x] Refactored `Secrets.swift` to runtime resolver (env → Keychain → local file)
- [x] Added `Secrets+Local.swift` (gitignored) + `.example` template
- [x] Fixed `.gitignore` (was pointing at the wrong path)
- [x] Updated `build.sh` to auto-stub `Secrets+Local.swift`
- [x] Updated CI to inject `OPENAI_API_KEY` into `Secrets+Local.swift` instead of `Secrets.swift`
- [x] Rewrote `CLAUDE.md` to match the actual project (no Supabase/web monorepo)
- [x] Rewrote `docs/ARCHITECTURE.md` with full file map + control flow
- [x] Wrote `docs/DEVELOPMENT.md` (setup, key config, debug)
- [x] Wrote `docs/RELEASE.md` (CI, signing, notarization, Homebrew tap)
- [x] Removed stale `docs/SUPABASE.md` template
- [x] Updated README setup section + linked new docs
