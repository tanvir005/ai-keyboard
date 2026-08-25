import SwiftUI
import NibKit

/// Spelling suggestions for the word being typed.
///
/// Sits above the tool row rather than replacing it. Reusing that row would
/// mean the AI tools vanish exactly while you are typing, which is when
/// reaching for Fix is most likely.
///
/// The strip keeps its height whether or not it has anything to show. A
/// keyboard that grows and shrinks under the thumb moves every key mid-sentence,
/// and the cost of that is worse than the cost of an empty row.
struct SuggestionStrip: View {
    let suggestions: [String]
    var onPick: (String) -> Void

    static let height: CGFloat = 38

    var body: some View {
        HStack(spacing: 0) {
            if suggestions.isEmpty {
                Color.clear
            } else {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, word in
                    if index > 0 {
                        Rectangle()
                            .fill(NibStyle.Palette.divider)
                            .frame(width: 1, height: 18)
                    }

                    Button {
                        onPick(word)
                    } label: {
                        Text(word)
                            .font(.system(size: 16, weight: .medium))
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
