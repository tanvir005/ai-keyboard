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
./setup.sh sk-proj-your-openai-key   # writes Secrets.xcconfig, generates the project
open Nib.xcodeproj
```

`setup.sh` exists because the steps it replaces are individually trivial and
collectively a trap: `Secrets.xcconfig` must exist before XcodeGen will run at
all, it is gitignored so no clone has it, and when it is missing the failure
names a config file rather than the key. Run it with no argument to set up
without a key — every AI tool then returns canned stub text.

The manual equivalent, if you prefer:

```bash
cp Secrets.xcconfig.example Secrets.xcconfig   # then paste your key into it
xcodegen generate
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

## The memory probe

Answers one question, and it is the most expensive assumption in the language
roadmap: **can a Chinese or Japanese dictionary of tens of megabytes live inside
a keyboard extension?** iOS gives an extension far less memory than an app and
kills it without warning — the keyboard just disappears mid-sentence.

In `NibKeyboard/KeyRows/KeyboardView.swift`:

```swift
enum KeyboardDebug {
    static let memoryProbe: ProbeMode = .mapped(megabytes: 30)
    static let showMemoryReadout = true
}
```

Run, open the keyboard in Messages, type for a minute. The footprint shows in
red in the top-right corner. If the keyboard vanishes, that size is over the
limit.

Walk it up until it dies — **5, 15, 30, 60** — then run the same sizes as
`.heap` instead of `.mapped`. The gap between the two is the answer:

- **Mapped** pages are clean. The kernel can evict and re-read them, so a
  memory-mapped dictionary can be much larger before anything dies.
- **Heap** pages are dirty. They count in full and cannot be reclaimed — this is
  what parsing a dictionary into Swift values costs.

If mapped survives where heap dies, the dictionary must be `mmap`ped and read in
place. That decides the shape of months of work, and it costs half a day to find
out.

Set both back to `.off` / `false` when the numbers are known. `NSLog` lines are
tagged `[nib]`.

### Signing

Both targets declare the `group.com.feinapps.aikeybord` App Group — the name
registered in the developer portal, spelling and all. It must match
`AppGroup.identifier` character for character; when it does not, nothing errors,
the shared container is simply never reachable. With a paid team, set that team
on both targets — Settings
will then reach the keyboard, along with history, presets and the quota counter.

**How to know it worked:** open Settings in the host app. If the App Group is not
reachable, an orange warning sits above the Keyboard section. When it is
reachable, the warning is gone and a switch flipped in the app changes the
keyboard the next time it opens.

Without the group, `AppGroup.defaults` silently falls back to this process's own
`UserDefaults` — every switch saves, reads back, and changes nothing. That
silence is why the warning exists.

If signing fails:

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

## Connecting the AI

The app calls **OpenAI directly** for every AI tool — Rewrite, Tone, Translate,
Fix, Synonyms, and Ask. With no key configured it makes no network calls at all:
every tool runs on `StubAPIClient` (canned transforms with a simulated delay),
which is a supported state, not a broken one.

### Adding your OpenAI key

The key is **not committed** — it lives in `ios/Secrets.xcconfig`, which is
gitignored. To set it up:

```bash
cd ios
cp Secrets.xcconfig.example Secrets.xcconfig   # once, on each machine
# open Secrets.xcconfig and paste your key (no quotes — xcconfig values are literal):
#     NIB_OPENAI_KEY = sk-proj-...
#     NIB_OPENAI_MODEL = gpt-5-mini            # optional; defaults to gpt-4o-mini
xcodegen generate
```

`project.yml` maps `Secrets.xcconfig` as the base config for **both Debug and
Release** (`configFiles`), so Xcode substitutes `$(NIB_OPENAI_KEY)` into each
target's `Info.plist` at build time. `NibBackend` reads it and hands Rewrite /
Tone / Translate / Fix / Synonyms / Ask to `OpenAIClient`. Leave the key empty
and those tools stay on the stub — nothing breaks.

Notes:

- **No `temperature` is sent.** The gpt-5 reasoning models reject any value but
  the default (1), and every other model already defaults to it, so omitting it
  is the one choice that works across models.
- **Model** defaults to `gpt-4o-mini`. Set `NIB_OPENAI_MODEL` to your exact
  model id (`gpt-5-mini`, `gpt-5`, `gpt-4o`, …). Reasoning models like the gpt-5
  family give higher quality but add latency and token cost per edit.

### Release / publishing builds

The key comes from the **local `Secrets.xcconfig`, not git**. So on any machine
that builds a release for the App Store — this Mac, another Mac, or CI — that
file must exist first, or `xcodegen generate` fails and the tools fall back to
the stub. Before you **Archive → Distribute**: confirm `ios/Secrets.xcconfig`
holds the real key, run `xcodegen generate`, then archive. The resulting IPA
ships with the key baked into the app and keyboard `Info.plist`.

### ⚠️ The key ships inside the app

A keyboard shipped with an API key in it is a key on **every phone that installs
it**, extractable from the IPA in minutes and billable to whoever owns it until
rotated. This is the deliberate trade `OpenAIClient` makes by calling OpenAI
directly. Mitigate it:

- Use a **dedicated, spend-limited** OpenAI key with a hard monthly cap.
- **Rotate** it regularly, and immediately if it leaks.
- Treat higher security (a proxy that holds the key server-side) as the real
  fix when there is something worth protecting — see the backend below.

### The backend (set aside)

An earlier design routed Fix through a hosted service in `backend/` so the
provider key could stay server-side. That wiring is intact but **dormant**:
`NibBackend.liveTools` is empty, so no tool is routed to it even when
`NIB_API_BASE_URL` is set. To hand a tool back to the service, put it in
`liveTools` (and remove it from `openAITools`) — `makeClient` reconnects the
layer automatically. `NIB_APP_SECRET` is not authentication; it ships inside the
app and only stops a scanner draining an open endpoint.

## Current state

All six tools call OpenAI when a key is configured; otherwise they come from
`StubAPIClient`. The Vercel backend is set aside (see above).

Also stubbed: purchases (the paywall flips a local flag) and the quota counter
(client-side, display only — real enforcement has to be server-side).
