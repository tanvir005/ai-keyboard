import SwiftUI
import NibKit

/// The AI's output. Tap a suggestion to swap it into the document; tap the
/// refresh glyph for another pass.
///
/// Always shows every alternative returned rather than picking one. "AI is
/// repetitive / gives one bad answer" is a recurring complaint in competitor
/// reviews (see FEATURE_RESEARCH.md) — offering choice is the mitigation.
struct SuggestionCard: View {
    let suggestions: [String]
    let label: String
    var onAccept: (String) -> Void
    var onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(label)
                    .font(NibStyle.Typography.sectionLabel)
                    .foregroundStyle(NibStyle.Palette.inkFaint)
                Text("↳ tap to insert")
                    .font(NibStyle.Typography.body(11))
                    .foregroundStyle(NibStyle.Palette.inkFaint)
                Spacer()
                Button(action: onRegenerate) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NibStyle.Palette.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                        Button { onAccept(suggestion) } label: {
                            Text(suggestion)
                                .font(NibStyle.Typography.body(14))
                                .foregroundStyle(NibStyle.Palette.ink)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 9)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(NibStyle.Palette.paper)
                                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 9)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 132)
        }
    }
}
