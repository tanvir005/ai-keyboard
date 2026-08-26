import SwiftUI
import NibKit

/// Corrections and completions for the word being typed.
///
/// Three slots, in the order both stock keyboards use: what you actually typed
/// on the left, in quotes, and the best alternative in the **middle** — which
/// is where the thumb goes and where the eye lands. The typed slot is how you
/// keep a word the dictionary does not know; tapping it dismisses the rest
/// until you move on to another word.
///
/// Shown only when it has something to say, and deliberately the shortest row
/// on the board — 32pt, so its arrival moves the keys as little as possible.
///
/// This was fixed-height for a while. Showing it conditionally overflowed the
/// board, because the input view does not resize in step with its content and
/// everything inside insisted on its own size. Both of those are now flexible,
/// so a late resize costs a few points of key height rather than the bottom
/// row of the keyboard.
///
/// The parent decides whether to show this, and holds it for a moment after it
/// empties. It is never rendered empty.
struct SuggestionStrip: View {
    let suggestions: WordSuggestions
    var onPick: (String) -> Void
    var onKeepTyped: (String) -> Void

    static let height: CGFloat = 32

    var body: some View {
        HStack(spacing: 0) {
            if suggestions.isEmpty {
                Color.clear
            } else {
                // No typed word means these are predictions of what comes
                // *next*, offered before anything has been typed — so there is
                // nothing to quote, and no one candidate to prefer over the
                // others.
                if !suggestions.typed.isEmpty {
                    slot("\u{201C}\(suggestions.typed)\u{201D}", emphasised: false) {
                        onKeepTyped(suggestions.typed)
                    }
                }

                ForEach(Array(suggestions.candidates.enumerated()), id: \.offset) { index, word in
                    if index > 0 || !suggestions.typed.isEmpty {
                        divider
                    }
                    slot(word, emphasised: index == 0 && !suggestions.typed.isEmpty) {
                        onPick(word)
                    }
                }
            }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background(NibStyle.Palette.keyboardAccessory)
    }

    private var divider: some View {
        Rectangle()
            .fill(NibStyle.Palette.keyLabel.opacity(0.25))
            .frame(width: 1, height: 16)
    }

    private func slot(
        _ text: String,
        emphasised: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 15, weight: emphasised ? .semibold : .regular))
                .foregroundStyle(emphasised ? NibStyle.Palette.keyLabel : NibStyle.Palette.keyLabel.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: Self.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emphasised ? "Replace with \(text)" : text)
    }
}
