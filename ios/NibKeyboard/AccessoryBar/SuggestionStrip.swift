import SwiftUI
import NibKit

/// Spelling suggestions for the word being typed.
///
/// Sits above the tool row rather than replacing it. Reusing that row would
/// mean the AI tools vanish exactly while you are typing, which is when
/// reaching for Fix is most likely.
///
/// Shown only when it has something to offer, so an idle keyboard is 38pt
/// shorter. The cost is that the keys move when it appears — the board grows,
/// and every key with it. Nib's own row of tools already makes it taller than
/// the stock keyboard, which is what tipped the balance toward reclaiming the
/// space; the trade is real either way.
///
/// The parent decides whether to show this. It is never rendered empty.
struct SuggestionStrip: View {
    let suggestions: [String]
    var onPick: (String) -> Void

    static let height: CGFloat = 38

    var body: some View {
        HStack(spacing: 0) {
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
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background(NibStyle.Palette.surface)
    }
}
