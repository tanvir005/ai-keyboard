import SwiftUI

/// Pill chip. Lives in NibKit rather than the host app because both targets
/// render it — the host app for tone presets, the keyboard for the tool row.
public struct NibChip: View {

    /// Which surface the chip is sitting on.
    ///
    /// The two targets no longer share a background: the app is still kraft
    /// paper, the keyboard now matches the system. Kraft ink and a kraft
    /// hairline read as smudges on system grey, so the chip has to be told
    /// where it is rather than assuming.
    public enum Surface {
        case paper
        case keyboard

        var label: Color {
            self == .paper ? NibStyle.Palette.ink : NibStyle.Palette.keyLabel
        }

        var border: Color {
            self == .paper
                ? NibStyle.Palette.kraftCardLine
                : NibStyle.Palette.keyLabel.opacity(0.28)
        }
    }

    let label: String
    var systemImage: String?
    var isActive: Bool
    var surface: Surface
    var action: () -> Void

    public init(
        label: String,
        systemImage: String? = nil,
        isActive: Bool = false,
        surface: Surface = .paper,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.isActive = isActive
        self.surface = surface
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
            .foregroundStyle(isActive ? NibStyle.Palette.onAccent : surface.label)
            .background {
                Capsule()
                    .fill(isActive ? NibStyle.Palette.red : .clear)
                    .overlay(
                        Capsule().strokeBorder(
                            isActive ? .clear : surface.border,
                            lineWidth: 1.4
                        )
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
