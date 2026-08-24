# Nib — iOS

Two targets, one shared package:

| | |
|---|---|
| `Nib/` | Host app — onboarding, Home, History, Presets, Settings, Paywall |
| `NibKeyboard/` | Keyboard extension — key rows + the AI toolbar |
| `NibKit/` | Shared code (settings, models, text-scope logic, design tokens) |

## Running it on the Mac

> **Xcode 16 or newer is required.** Current XcodeGen writes project format
> `objectVersion 77`; Xcode 15 refuses to open it with *"a future Xcode project
> file format"*. If you are stuck on Xcode 15, say so — the format can be pinned
> in `project.yml` instead of upgrading.

The `.xcodeproj` is **not committed** — it is generated from `project.yml`.

```bash
brew install xcodegen        # once
git pull
cd ios
xcodegen generate            # creates Nib.xcodeproj
open Nib.xcodeproj
```

Then in Xcode: select the **Nib** scheme → a simulator or device → Run.

Re-run `xcodegen generate` whenever `project.yml` changes or files are
added/removed. It is safe to run any time; it never touches source.

### Trying the keyboard

The host app runs on its own, but the keyboard needs enabling by hand — iOS has
no API to do it programmatically:

1. Run the app once (this installs the extension).
2. **Settings → General → Keyboard → Keyboards → Add New Keyboard → Nib**
3. Tap **Nib** in that list → enable **Allow Full Access**.
4. Open Messages or Notes, long-press the 🌐 globe key, choose **Nib**.

Without Full Access the keyboard still types normally — the tool row is
replaced by a banner explaining how to turn it on. That degradation is
intentional and worth checking.

### Signing

Both targets declare the `group.com.nib.app` App Group. With a personal team,
Xcode will usually provision it automatically on first build. If signing fails:

- Set your team on both targets (Signing & Capabilities), **or**
- For a quick look at the UI only, delete the `CODE_SIGN_ENTITLEMENTS` lines
  from `project.yml` and regenerate. The app still runs; the host app and
  keyboard just stop sharing state (`AppGroup.defaults` falls back to
  `UserDefaults.standard`).

Bundle IDs are placeholders (`com.nib.app`, `com.nib.app.keyboard`) — change
them in `project.yml` and both `.entitlements` files together.

## Tests

```bash
cd ios/NibKit && swift test
```

Runs without a simulator. `TextContextResolver` is deliberately UIKit-free so
its boundary and grapheme math is verifiable here rather than only on-device.

## Current state

Suggestions come from `StubAPIClient` — canned transforms of whatever you type,
with a simulated delay. No network, no API keys, no backend. `NibAPIClient` is
the seam a real client drops into later.

Also stubbed: purchases (the paywall flips a local flag) and the quota counter
(client-side, display only — real enforcement has to be server-side).
