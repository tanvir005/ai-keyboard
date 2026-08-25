import SwiftUI
import NibKit

/// Spelling suggestions for the word being typed.
///
/// Sits above the tool row rather than replacing it. Reusing that row would
/// mean the AI tools vanish exactly while you are typing, which is when
/// reaching for Fix is most likely.
///
/// Always present, and deliberately the shortest row on the board.
///
/// Showing it only when it had words was tried and reverted: the input view
/// does not grow in step with its content, so the board overflowed its own
/// bounds — clipping the words at the top and the bottom key row at the
/// bottom. A keyboard whose height never changes cannot get out of step with
/// the space the system has given it.
///
/// So the row stays, and pays for itself by being small: 32pt against the 42pt
/// of a key row. Enough to read and hit, little enough that an empty one costs
/// almost nothing.
struct SuggestionStrip: View {
    let suggestions: [String]
    var onPick: (String) -> Void

    static let height: CGFloat = 32

    var body: some View {
        HStack(spacing: 0) {
            if suggestions.isEmpty {
                Color.clear
            } else {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, word in
                    if index > 0 {
                        Rectangle()
                            .fill(NibStyle.Palette.divider)
                            .frame(width: 1, height: 16)
                    }

                    Button {
                        onPick(word)
                    } label: {
                        Text(word)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(NibStyle.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: Self.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Replace with \(word)")
                }
            }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background(NibStyle.Palette.surface)
    }
}
