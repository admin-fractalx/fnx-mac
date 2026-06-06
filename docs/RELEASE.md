# Release — FnX

How to ship a signed, notarized build of FnX, either manually from your machine or through GitHub Actions.

## Distribution channels

| Channel | Source of truth |
|---------|-----------------|
| GitHub Releases | `softprops/action-gh-release` step in `.github/workflows/release.yml` |
| Homebrew tap (`admin-fractalx/homebrew-tap`) | Auto-updated `Casks/fnx.rb` at the end of the same workflow |
| In-app updater | Polls `https://api.github.com/repos/admin-fractalx/fnx-mac/releases/latest` (`AppDelegate.checkForUpdates`) |

Bumping a release ⇒ in-app users get an "Update Available" prompt automatically, and `brew upgrade --cask fnx` works.

## Local release (one-off, from your machine)

```bash
# 1. Make sure the production OpenAI key is in Secrets+Local.swift
#    (or set OPENAI_API_KEY env var — it gets baked in at build time)
$EDITOR Sources/FnX/Helpers/Secrets+Local.swift

# 2. Build, sign, zip
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
./release.sh 1.2.3

# 3. (Optional) Notarize via Apple
NOTARIZE=1 NOTARY_KEYCHAIN_PROFILE="your-profile" ./release.sh 1.2.3

# Outputs:
#   FnX.app            (signed + notarized bundle)
#   FnX-1.2.3.zip      (ditto-zipped for distribution)
```

To create the notarization profile once:

```bash
xcrun notarytool store-credentials "your-profile" \
  --apple-id "you@example.com" \
  --team-id "ABCDE12345" \
  --password "app-specific-password-from-appleid.apple.com"
```

Then upload the `.zip` to GitHub Releases under tag `v1.2.3`.

## CI release (preferred — automated on every `main` push)

`.github/workflows/release.yml` runs on every push to `main` and does the full pipeline:

1. **Auto-bumps the patch version** from the latest git tag (`v1.2.3` → `v1.2.4`)
2. **Pushes the new tag**
3. **Injects the OpenAI key** from the `OPENAI_API_KEY` repo secret into `Sources/FnX/Helpers/Secrets+Local.swift`
4. **Builds** via `BUILD_FOR_RELEASE=1 ./build.sh`
5. **Bumps `Info.plist` version** to match the tag
6. **Imports the Developer ID certificate** into a temporary keychain
7. **Signs** all binaries + bundles
8. **Zips, notarizes, staples**
9. **Creates a GitHub Release** with the signed zip attached
10. **Updates the Homebrew tap** with the new version + SHA256

### Required GitHub secrets

Set these on the repo (`Settings → Secrets and variables → Actions`):

| Secret | What it is | Where to get it |
|--------|------------|-----------------|
| `OPENAI_API_KEY` | Production OpenAI key baked into release builds | platform.openai.com/api-keys |
| `SIGNING_IDENTITY` | `Developer ID Application: Your Name (TEAM_ID)` | Keychain Access → cert name |
| `DEVELOPER_ID_CERTIFICATE` | Base64-encoded `.p12` of the Developer ID cert + private key | `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_PASSWORD` | Password set when you exported the `.p12` | You chose it |
| `APPLE_ID` | Apple ID email used for notarization | developer.apple.com login |
| `APPLE_TEAM_ID` | 10-char team ID | developer.apple.com/account → Membership |
| `APPLE_APP_PASSWORD` | App-specific password for the Apple ID | appleid.apple.com → Sign-In Security → App-Specific Passwords |
| `TAP_GITHUB_TOKEN` | PAT with `contents:write` on `admin-fractalx/homebrew-tap` | github.com/settings/tokens |

If `TAP_GITHUB_TOKEN` is missing, the Homebrew step is skipped (release still publishes).

### Exporting the Developer ID `.p12`

1. Open **Keychain Access** → log-in keychain
2. Find `Developer ID Application: …` (must have a disclosure triangle showing the private key)
3. Right-click → **Export Items…** → `.p12` format → set a password
4. `base64 -i ~/path/to/cert.p12 | pbcopy` and paste into the `DEVELOPER_ID_CERTIFICATE` secret

## Skipping a release

The workflow runs on every push to `main`. If you don't want to ship, push to a branch and open a PR — the workflow won't run until merge.

## Cutting a major/minor version manually

The CI only auto-bumps the patch. To cut `v2.0.0`:

```bash
git tag v2.0.0
git push origin v2.0.0
# Next push to main will auto-bump from v2.0.0 → v2.0.1
```

## LemonSqueezy reference

The license backend isn't touched at release time, but here's where the configuration lives so you can audit/change it:

| Thing | Where |
|-------|-------|
| Activate / validate / deactivate API calls | `Sources/FnX/Services/LicenseManager.swift:92-160` |
| Monthly checkout URL (`4e5e9629-…`) | `Sources/FnX/ViewModels/LicenseViewModel.swift:15` |
| Annual checkout URL (`00ec8b3f-…`) | `Sources/FnX/ViewModels/LicenseViewModel.swift:16` |
| LemonSqueezy store dashboard | https://fractalx.lemonsqueezy.com |

## After a release

- [ ] Verify the GitHub Release appears with the signed zip attached
- [ ] `brew upgrade --cask fnx` from a clean machine to test the tap
- [ ] Download the zip, unzip, drag to `/Applications`, launch — Gatekeeper should accept it without warnings
- [ ] Open the in-app menu → "Check for Updates" from an older build to confirm the updater sees it
