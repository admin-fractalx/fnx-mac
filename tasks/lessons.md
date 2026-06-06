# Lessons — FnX

Patterns and rules captured from user corrections or non-obvious decisions. Append, don't rewrite.

---

## 2026-06-06 — Don't ship hardcoded API keys in source

**Rule:** Never put a real API key in a committed Swift file. Use `Secrets.openAIAPIKey` (runtime resolver) and configure via env var, Keychain, or the gitignored `Secrets+Local.swift`.

**Why:** A real OpenAI key was committed to `Sources/FnX/Helpers/Secrets.swift` and lived in git history for months. The `.gitignore` had a typo'd path (`Sources/FnX/Secrets.swift` vs the actual `Sources/FnX/Helpers/Secrets.swift`), so the safety net never engaged. CI was also overwriting the committed file at build time, which made the leak feel "intentional" and easy to miss.

**How to apply:** Before adding any secret to a `.swift` file, check whether the path matches a `.gitignore` entry **exactly** (`git check-ignore -v <path>`). If you need a value at compile time, put it in `Sources/FnX/Helpers/Secrets+Local.swift` (already gitignored) and access it through `Secrets.<name>`. Never let CI write to a tracked secrets file.

---

## 2026-06-06 — Global CLAUDE.md rules don't always apply

**Rule:** The global FractalX rules assume a monorepo (`app/` + `web/`) with Supabase. FnX is a single-target macOS Swift app — those rules don't apply. The project-level `CLAUDE.md` overrides where they conflict.

**Why:** Following the global rules blindly led to writing a `docs/SUPABASE.md` template for a project that has no backend at all. Wasted doc surface, misleading for new contributors.

**How to apply:** When starting work on a FractalX project, read both the global and the project `CLAUDE.md` and treat the project-level one as the source of truth for repo layout, tech stack, and doc conventions.
