# Nib — Competitor Research

Source material: `C:\Users\Lenovo\Desktop\smart keyboard\` — screenshots + App Store review research for 10 AI keyboard / voice-typing apps (Aug 2026).

Apps reviewed: TypeOn/Type Now, Facemoji, Grammarly Keyboard, KeyAI, Remarkable AI, Rizzkey, Microsoft SwiftKey, TypeAI, Wispr Flow, Typeless, plus a generic "AI Keyboard" app found in the `typeless flow` folder.

## Feature superset

**AI text tools (near-universal — table stakes for Nib):**
Grammar/spelling fix, Rewrite/paraphrase (multiple alternatives), Tone changer, Translate (100+ languages; TypeOn also does WhatsApp voice-note translation), Ask-AI-anything chat, Summarize, Synonyms, Reply generator, Continue writing, Humanizer.

**Extras seen in specific apps (not core):**
- Email Writer as its own in-app tool, not just a keyboard action (TypeAI, TypeOn)
- OCR / extract text from photos (TypeOn)
- Voice-first dictation with live waveform — a different paradigm entirely (Wispr Flow, Typeless)
- AutoPaste / saved snippets + custom AI commands (KeyAI)
- Emoji/sticker/theme/font shop, "Rizz"/celebrity/caption presets, text-art generator (Facemoji, Rizzkey)
- Swipe-to-type (SwiftKey)
- Coin-based cosmetic economy (Rizzkey)

**Onboarding/trust patterns worth copying:**
- Explicit "your text is sent to OpenAI" disclosure screen (KeyAI)
- Annotated Full-Access permission dialog, red-circling the scary sentence (Rizzkey, Remarkable AI)
- Visible free-quota counter, "2 left today" (KeyAI)
- Gamified retention stats — "your week in review", keystrokes saved (Grammarly, SwiftKey)
- Regenerate/refresh button directly on the suggestion (Remarkable AI)
- Model transparency — "Developed on GPT-4o", model switcher (TypeAI)

**Monetization patterns:**
- Nearly universal: 3–7 day free trial → subscription
- Common tiers: Weekly $3.99–5.99, Yearly $29.99–89.99, Lifetime $49.99–59.99 (always shown discounted from a higher "was" price)
- Daily free-use caps typically 2–3/day — stingier than Nib's plan

## Complaints to design against

1. **Confusing/aggressive pricing** — post-launch price hikes (TypeOn $35→$90/yr), A/B-tested tier chaos (TypeAI, KeyAI), paywall hit after ~5 uses (Rizzkey).
2. **"Allow Full Access" is the #1 fear** in reviews across nearly every app — handled well by KeyAI/Rizzkey's annotated approach, handled poorly (silently) by others.
3. **Performance complaints dominate 1-star reviews** — laggy keys, keyboard reverting to default, reliability dropping specifically *after* payment (Wispr Flow). The keyboard shell must never block on an AI network call.
4. **"AI is dumb"/repetitive, over-filtered output** (Facemoji, TypeAI) — always offer 2–3 alternatives, never force one output, make regenerate easy.
5. **Missing basic keyboard fundamentals** (autocorrect, cursor control, punctuation placement) tank ratings even when the AI features are good (SwiftKey, TypeAI) — table stakes, not a differentiator, but fatal if absent.
6. **Subscription/restore-purchase bugs, unresponsive support** (Rizzkey, TypeOn) — an ops commitment, not a design one.

## Scope decision

Rather than cram every feature above into one v1 (several are genuinely different products — voice-first dictation, emoji/theme shop, and a dating-reply generator don't share a coherent identity with a rewrite/tone/translate toolbar), sequence it:

- **v1 (core, this design pass):** Rewrite, Tone, Fix Grammar, Translate, Synonyms, Reply, Ask AI — toolbar-above-keyboard mechanic, visible free-quota counter, honest single pricing screen, disclosure + annotated Full Access screens.
- **v1.5:** Email Writer as standalone tool, saved snippets, custom commands, summarize.
- **v2:** voice-dictation mode, theme/font/emoji shop, OCR.
