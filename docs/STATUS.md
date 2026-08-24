# Status — 25 Aug 2026

## Where things stand

Repo: https://github.com/tanvir005/ai-keyboard (branch `main`)

The full iOS scaffold: host app (8 screens), keyboard extension (QWERTY + AI
toolbar), and the shared NibKit package. Suggestions come from `StubAPIClient` —
canned transforms, no backend, no API keys.

## ✅ CI is green on `main`

Everything compiles. The workflow builds both targets and runs the NibKit tests
on every push.

### The failure that took four rounds to find

The first runs failed with `xcodebuild: error: Unable to read project`. The
cause was not Swift at all:

> The project 'Nib' cannot be opened because it is in a future Xcode project
> file format (77).

Current XcodeGen writes `objectVersion 77`, which needs **Xcode 16**. The
`macos-14` runner ships Xcode 15.4. Fixed by moving CI to `macos-15`.

**A Mac building this repo needs Xcode 16+ for exactly the same reason.** If
only Xcode 15 is available, pin the format in `project.yml` rather than
upgrading.

Two things learned while debugging, worth keeping:

- **Raw job logs need admin rights even on a public repo.** Annotations do not.
  The workflow re-emits each compiler error as an annotation so failures explain
  themselves via the public API.
- **GitHub's Actions *web UI* cannot be read reliably by fetching** — it once
  reported a confident false "success". The badge SVG
  (`/actions/workflows/<file>/badge.svg`) is static and trustworthy; so is the
  REST API.

## What is verified, and what is not

**Verified on a real compiler:**
- The whole project builds — app target and keyboard extension.
- NibKit unit tests pass, including the text-scope logic: the exact-suffix
  invariant and grapheme counting. `"hi 👨‍👩‍👧‍👦"` is 4 `Character`s but 14 UTF-16
  units; counting wrong would over-delete by 10 and shred the emoji.
- XcodeGen spec generates a valid two-target project.

**Not verified — never run on a device.** Compiling is not working. Typing feel,
keyboard height, Full Access degradation, and whether keys stay responsive
during a request all need real hardware. See `docs/MAC_CHECKPOINTS.md`.

## Next session

1. Build on the Mac — `ios/README.md` for setup (**needs Xcode 16+**),
   `docs/MAC_CHECKPOINTS.md` for the walkthrough.
2. Then either polish the UI or start the backend (`docs/` has the full plan).

Minor cleanup available: the workflow triggers on both `push` and
`pull_request`, so every PR builds twice. Harmless and free on a public repo.

## Deliberate decisions worth not re-litigating

- **Reply is cut from v1** — a keyboard extension cannot read the other person's
  message. Six tools ship.
- **No selection API exists.** Nib operates on an exact suffix of the text
  before the cursor and replaces it by deleting precisely what it sent.
- **Light appearance only** — the kraft palette is a committed look; the mockup
  renders every screen on constant paper stock.
- **Quota is client-side and display-only.** Real enforcement must be
  server-side, or it is trivially bypassed.
