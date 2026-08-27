# Nib

**The AI editor built into your keyboard.**

An iOS keyboard extension that rewrites, fixes tone, translates and edits text
inline — wherever you're already typing. No switching to a separate AI app.

## Where things are

```
ios/                 Swift — host app + keyboard extension + shared package
docs/screens/        The original concept mockup and competitor research
backend/             Vercel Functions API (not built yet)
android/             Future phase
```

- **`docs/screens/nib-concept.html`** — the 10-screen visual concept the app is
  built from. Open it in a browser.
- **`docs/screens/FEATURE_RESEARCH.md`** — teardown of 10 competitor keyboards
  that set the v1 scope. Worth reading before proposing features.
- **`ios/README.md`** — how to build and run it.

## Status

Runnable end to end. All six AI tools call **OpenAI directly** once a key is
set (`ios/Secrets.xcconfig` — see [ios/README.md](ios/README.md#connecting-the-ai));
with no key they run on canned stubs, so the app works either way.

| Working | Stubbed | Not started |
|---|---|---|
| All 8 host-app screens | Purchases (flips a local flag) | Real StoreKit |
| History + Presets screens | Quota counter (client-side) | Android |
| Custom QWERTY keyboard | | |
| AI toolbar + tap-to-insert | | |
| Six AI tools via OpenAI (with key) | | |

## v1 scope: six tools

Rewrite · Tone · Fix · Translate · Synonyms · Ask AI

**"Reply" is cut from v1.** The concept mockup shows it as "a draft, from their
last message", but a keyboard extension can only read the text field being typed
into — the other person's message is app UI that no public API exposes. Shipping
it would underdeliver on its own tagline. Revisit in v1.5 with an explicit paste
step.

## Three constraints that shaped the design

1. **No text selection API.** `UITextDocumentProxy` never exposes
   `selectedTextRange`. Nib doesn't pretend to know what you selected — it
   operates on the text before the cursor and replaces it by deleting exactly
   what it sent. See `TextContextResolver`.
2. **Full Access gates all networking.** Without it the extension cannot make a
   single request. Nib degrades to a plain keyboard rather than breaking.
3. **The keyboard must never block on the network.** Typing stays live while a
   request is in flight. Competitor 1-star reviews are dominated by lag.

## Privacy commitments

The onboarding screen makes four promises. They are requirements, not copy:

- Text is sent **only** when you tap a tool — never continuously
- Only the relevant scope is sent — not keystroke history
- Nothing is stored server-side after the response
- Revoke Full Access anytime; the keyboard keeps working

Edit history is stored **on the device only** and can be cleared from Settings.

## Development

Code is authored on Windows and built on a Mac. `.github/workflows/ios-build.yml`
compiles both targets and runs the NibKit tests on every push, so build breaks
surface before anyone opens Xcode.
