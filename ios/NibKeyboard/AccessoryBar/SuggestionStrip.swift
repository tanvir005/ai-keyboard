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
/// Always present, and deliberately the shortest row on the board.
///
/// Showing it only when it had words was tried and reverted: the input view
/// does not grow in step with its content, so the board overflowed its own
/// bounds — clipping the words at the top and the bottom key row at the
/// bottom. A keyboard whose height never changes cannot get out of step with
/// the space the system has given it.
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
                slot("\u{201C}\(suggestions.typed)\u{201D}", emphasised: false) {
                    onKeepTyped(suggestions.typed)
                }

                ForEach(Array(suggestions.candidates.enumerated()), id: \.offset) { index, word in
                    divider
                    // Only the first is emphasised: it is the one inline
                    // completion is already showing in the field, so the two
                    // must agree about which word is being offered.
                    slot(word, emphasised: index == 0) { onPick(word) }
                }
            }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background(NibStyle.Palette.surface)
    }

    private var divider: some View {
        Rectangle()
            .fill(NibStyle.Palette.divider)
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
                .foregroundStyle(emphasised ? NibStyle.Palette.ink : NibStyle.Palette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: Self.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emphasised ? "Replace with \(text)" : text)
    }
}
