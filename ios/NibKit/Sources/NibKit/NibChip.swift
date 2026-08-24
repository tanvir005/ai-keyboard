import SwiftUI

/// Pill chip. Lives in NibKit rather than the host app because both targets
/// render it — the host app for tone presets, the keyboard for the tool row.
public struct NibChip: View {
    let label: String
    var systemImage: String?
    var isActive: Bool
    var action: () -> Void

    public init(
        label: String,
        systemImage: String? = nil,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                }
                Text(label).font(NibStyle.Typography.body(12.5, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isActive ? Color(hex: 0xFBF3E8) : NibStyle.Palette.ink)
            .background {
                Capsule()
                    .fill(isActive ? NibStyle.Palette.red : .clear)
                    .overlay(
                        Capsule().strokeBorder(
                            isActive ? .clear : NibStyle.Palette.kraftCardLine,
                            lineWidth: 1.4
                        )
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
