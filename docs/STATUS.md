# Status — 25 Aug 2026

## Where things stand

Repo: https://github.com/tanvir005/ai-keyboard (branch `main`)

The full iOS scaffold is written and pushed: host app (8 screens), keyboard
extension (QWERTY + AI toolbar), and the shared NibKit package. Suggestions come
from `StubAPIClient` — canned transforms, no backend, no API keys.

## ⚠️ CI is FAILING — this is the first thing to deal with

The **iOS** workflow ran on commit `26bf71c` and failed. None of this Swift has
ever been compiled — it was authored on Windows, where Xcode does not exist — so
compile errors are expected, not surprising.

**The failure has not been diagnosed yet.** GitHub's Actions UI could not be read
without authentication, so the actual error text is unknown. Get it via either:

```bash
# option A — install the GitHub CLI, then:
gh run list --workflow=ios-build.yml
gh run view --log-failed
```

or just open the Actions tab in a browser, click the failed run, and copy the
red step's output.

### Where the failure most likely is

In rough order of likelihood — the run failed fast, which points at the early
steps:

1. **`xcodegen generate`** — `ios/project.yml` has never been executed. If the
   spec is malformed, nothing downstream runs. Most suspect: the nested
   `NSExtension` dictionary in the keyboard target's `info:` block, and the
   local `packages:` path.
2. **`swift test`** — a NibKit compile error would stop here. NibKit is built
   for macOS purely so these tests can run headlessly; anything accidentally
   iOS-only in that target would fail here but not in the app.
3. **`xcodebuild`** — genuine SwiftUI compile errors in the app or extension.
   Expect several; `@Observable`/`@Bindable` usage and the `PreferenceKey`
   height plumbing in `KeyboardViewController` are the least-certain parts.

## What was verified, and what wasn't

**Verified:**
- Text-scope logic — the exact-suffix invariant and grapheme counting were
  checked against a reference implementation. `"hi 👨‍👩‍👧‍👦"` is 4 `Character`s but
  14 UTF-16 units; counting wrong would over-delete by 10 and shred the emoji.
- No cross-target reference violations (extension never touches host-app types).
- No missing `import NibKit`.
- Module/type collision caught and fixed: NibKit's design-token enum was named
  `Nib`, same as the app's module. Renamed to `NibStyle`.

**Not verified — nothing here has been compiled or run.**

## Next session

1. Get the CI failure text (above) and fix the errors.
2. Once CI is green, build on the Mac: `ios/README.md` has setup;
   `docs/MAC_CHECKPOINTS.md` has the walkthrough list.
3. Then either polish the UI or start the backend (`docs/` has the full plan).

## Deliberate decisions worth not re-litigating

- **Reply is cut from v1** — a keyboard extension cannot read the other person's
  message. Six tools ship.
- **No selection API exists.** Nib operates on an exact suffix of the text
  before the cursor and replaces it by deleting precisely what it sent.
- **Light appearance only** — the kraft palette is a committed look; the mockup
  renders every screen on constant paper stock.
- **Quota is client-side and display-only.** Real enforcement must be
  server-side, or it is trivially bypassed.
