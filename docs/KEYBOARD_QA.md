# Keyboard QA checklist

Benchmarked against **Apple's stock keyboard** and **Gboard** — the two things
users will unconsciously compare Nib to. `FEATURE_RESEARCH.md` is blunt about
why this matters: missing keyboard *fundamentals* sink ratings even when the AI
is good.

## How to read this

| Mark | Meaning |
|---|---|
| ⚠️ | **Already confirmed missing from the code.** Don't hunt for it — just decide if you care. |
| ☐ | Genuinely needs your hands. Only a real device can answer. |

Test in **Messages and Notes**, light and dark, before reporting.

---

## 1. Key input mechanics

The most likely source of the trouble you felt while typing.

- ⚠️ **Sliding off a key still types it.** `KeyboardView.swift:74` — the gesture
  fires `action()` on release no matter where your finger ended up. Press `q`,
  drag to the far side of the keyboard, release: you still get `q`. Apple and
  Gboard both let you slide to correct, or off the keyboard to cancel.
- ⚠️ **Hit area is exactly the visible key** (`KeyboardView.swift:63`), with
  5pt gaps that belong to nobody. Apple extends each key's touch area into the
  surrounding gap, so edge taps still land. Expect dropped letters at key edges.
- ⚠️ **No key preview popup.** Apple pops an enlarged bubble above your finger —
  the main reason you can tell you hit the right key. Nib only shrinks the key
  6%, which your finger is covering.
- ⚠️ **No backspace repeat.** Hold delete: Apple and Gboard delete continuously,
  then accelerate to whole words. Nib deletes exactly one character.
- ⚠️ **No long-press alternates.** No `é`, no `à`, no alternate punctuation.
- ☐ Type a fast sentence you know by heart. Count dropped, doubled, and wrong
  letters. Then type the same sentence on Apple's keyboard and compare.
- ☐ Type with thumbs while walking. This is where hit-area problems show up.

## 2. Shift and capitals

- ✅ Starts shifted, auto-unshifts after one character. *(Implemented.)*
- ⚠️ **No caps lock.** Double-tapping shift does nothing.
- ⚠️ **No auto-capitalisation.** Type `hi. how are you` — the `h` after the full
  stop stays lowercase. Apple and Gboard both capitalise it.
- ☐ Is the active shift state (red fill) obvious at a glance?

## 3. Space and delete

- ⚠️ **No double-space → `. `** — universal on both keyboards.
- ⚠️ **No space long-press cursor trackpad.**
- ⚠️ **No swipe-left-on-delete to remove a word** (Gboard).
- ☐ Is the space bar wide enough? It's 5 units against Apple's ~5.

## 4. Sound and haptics — both confirmed dead

- ⚠️ **The Sound toggle does nothing.** `KeyboardViewController` calls
  `UIDevice.current.playInputClick()` but never conforms to
  `UIInputViewAudioFeedback`, so iOS ignores the call entirely.
- ⚠️ **The Haptics toggle does nothing.** The switch exists
  (`SettingsView.swift:64`) and the setting is stored, but there is no haptic
  code anywhere in the keyboard.
- ☐ Confirm with both toggles on: no click, no tap. A silent, still keyboard is
  the single biggest "this feels cheap" signal versus Apple.

## 5. Layout and sizing

- ⚠️ **The middle row is not inset.** Apple indents `a`–`l` by half a key so
  nine keys sit under ten. Nib stretches nine keys across the full width, making
  them ~11% wider than the row above, and nothing lines up vertically. This is
  the most visible layout difference from every keyboard you've used.
- ⚠️ **No emoji key.** Bottom row is `123 · 🌐 · space · return`. Apple and
  Gboard both have a dedicated emoji key; users look for it first.
- ⚠️ **The return key never changes label.** No `returnKeyType` handling, so it
  says `return` in Messages where Apple says **Send**, and in Safari where Apple
  says **Go** or **Search**.
- ⚠️ Keyboard height is a hard-coded **258pt** (key area 214pt), with no
  safe-area inset.
- ☐ Put Nib and Apple's keyboard side by side (screenshot both). Is Nib
  noticeably shorter, taller, or off?
- ☐ Does the bottom row collide with the home indicator?
- ☐ **Rotate to landscape.** The height is a constant — does it swallow the
  screen?
- ☐ Check on Messages *and* Notes — clipped rows, wrong background behind.

## 6. Text intelligence

- ⚠️ **No autocorrect, no predictions, no spell-check underline, no smart
  quotes.** The strip where Apple and Gboard put suggestions is the AI toolbar
  instead. `predictionEnabled` exists in settings but nothing implements it.
- ☐ **The judgement call:** after ten minutes of real typing, is a keyboard with
  no autocorrect usable? This is the largest single gap versus both competitors,
  and it needs your verdict, not mine.

## 7. Visual design

- ☐ **Dark mode.** The kraft cream palette is fixed for both appearances. Open a
  dark-mode app: does the keyboard read as a deliberate choice or a bug?
- ☐ Key labels: 21pt characters, 13pt `space`/mode, 16pt function. Legible at
  arm's length?
- ☐ The hard offset shadow (`radius: 0, y: 1`) — intentional letterpress, or
  just misaligned?
- ☐ Function keys use a darker fill than letters. Right emphasis, or does it
  make shift and delete look disabled?
- ☐ Accessory bar height against Apple's suggestion strip — does the AI row eat
  too much screen in Messages?
- ☐ Does the red return key read as "send", or as "danger"?

## 8. Accessibility

- ⚠️ **No accessibility labels on keys.** VoiceOver will read `⇧` and `⌫` as raw
  glyphs rather than "shift" and "delete".
- ☐ Largest Dynamic Type setting — do labels clip?

---

## Reporting back

Two things are worth more than a full pass:

1. **Which three of these annoy you most** while actually typing.
2. **Anything that happened that isn't on this list** — that's the valuable
   half, because it's the part I couldn't predict from reading code.
