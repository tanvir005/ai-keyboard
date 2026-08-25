import SwiftUI
import NibKit

/// The emoji page.
///
/// Not another `KeyboardMode` layout, because it is not a key grid: it scrolls,
/// it has categories, and its cells are content rather than keys. Sharing the
/// grid code would mean bending both out of shape.
///
/// There is no public API to open the system emoji keyboard from an extension,
/// so a keyboard that replaces the stock one has to bring its own — see
/// `EmojiCatalog` for why the set is curated rather than complete.
struct EmojiPageView: View {
    var onEmoji: (String) -> Void
    var onBackspace: () -> Void
    var onLetters: () -> Void
    var onPress: () -> Void

    @State private var selected = EmojiCatalog.categories.first?.id ?? ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 8)

    private var current: [String] {
        EmojiCatalog.categories.first { $0.id == selected }?.emoji ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(current, id: \.self) { glyph in
                        Button {
                            onPress()
                            onEmoji(glyph)
                        } label: {
                            Text(glyph)
                                .font(.system(size: 27))
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 4)
            }
            // Resets the scroll position when the category changes, so a new
            // tab opens at its own top rather than wherever the last one was.
            .id(selected)

            footer
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            functionKey("ABC", width: 46) {
                onPress()
                onLetters()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(EmojiCatalog.categories) { category in
                        Button {
                            onPress()
                            selected = category.id
                        } label: {
                            Text(category.symbol)
                                .font(.system(size: 19))
                                .frame(width: 34, height: 32)
                                .background {
                                    if category.id == selected {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(NibStyle.Palette.keyWide)
                                    }
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(category.id)
                    }
                }
            }

            functionKey("⌫", width: 46) {
                onPress()
                onBackspace()
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 8)
    }

    private func functionKey(
        _ label: String,
        width: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NibStyle.Palette.ink)
                .frame(width: width, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(NibStyle.Palette.keyWide)
                        .shadow(color: .black.opacity(0.18), radius: 0, y: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
