# Mac checkpoints

The code is authored on Windows, where there is no Xcode. CI compiles every
push (`.github/workflows/ios-build.yml`), but compilation is not behaviour —
some things can only be judged on a real device. This is the list of those
things, so Mac time goes to *running* the app rather than reading diffs.

## Checkpoint 1 — first run (now)

```bash
brew install xcodegen
cd ios && xcodegen generate && open Nib.xcodeproj
```

**Host app**

- [ ] App launches into onboarding, all five screens advance
- [ ] "Skip" on screen 1 jumps straight to Home
- [ ] Home renders: greeting, quota chip, streak, preset chips, empty history
- [ ] Tabs work: Home / History / Presets / Settings
- [ ] Presets → "+" → create a custom tone → it appears on Home's chip row
- [ ] Settings toggles persist across an app relaunch
- [ ] Paywall opens from Settings → Manage subscription; picking a plan changes
      the CTA label ("Start 7-day free trial" vs "Buy Nib Pro")

**Keyboard** — needs enabling by hand, see `ios/README.md`

- [ ] Nib appears under Settings → General → Keyboard → Keyboards
- [ ] Selecting Nib from the globe long-press switches to it
- [ ] **Before granting Full Access:** keys type normally, and the tool row is
      replaced by the "Turn on Full Access" banner. This graceful degradation is
      a promise the onboarding makes — confirm it actually holds.
- [ ] After granting Full Access: tool chips appear
- [ ] Type a sentence → tap **Fix** → suggestions appear → tap one → it replaces
      the text cleanly, with no leftover or over-deleted characters
- [ ] **Type an emoji (👨‍👩‍👧‍👦) mid-sentence, then run a tool and accept.** This is
      the grapheme-cluster path; if `deleteCount` were wrong it would shred the
      emoji. Unit-tested, but worth seeing once for real.
- [ ] Tap **Tone** → sub-chips appear → picking one regenerates
- [ ] Tap **Ask AI** → prompt field + suggestion chips work
- [ ] Regenerate (↻) returns a fresh result
- [ ] Keys stay responsive *while* a suggestion is loading — this is the
      non-negotiable one. If typing stalls during a request, stop and report it.
- [ ] Accepted edits show up on Home and in History
- [ ] Keyboard height looks right; no clipped rows in Messages *and* Notes

**Judgement calls worth reporting back**

- Key size and spacing — does it feel like a real keyboard or a mockup of one?
- Is the accessory bar too tall? It eats screen space in Messages.
- Does the kraft palette hold up on a real display, next to iOS's own chrome?

## Not yet worth checking

Stubbed, so there is nothing real to verify: purchases (flips a local flag),
AI quality (canned transforms), quota enforcement (client-side only).

## Later checkpoints

- **After the backend lands:** real latency on poor connections, quota 429
  handling, StoreKit sandbox purchase → server receipt validation round trip.
- **Before submission:** Instruments memory pass on the extension (it runs under
  a tight ceiling), accessibility audit, privacy nutrition labels matched to
  what the backend actually does.
