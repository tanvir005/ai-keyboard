import SwiftUI

/// Design tokens lifted from the concept mockup (docs/screens/nib-concept.html).
///
/// Note on appearance: the mockup renders every phone screen on a constant
/// `#FBF8EF` paper background in both light and dark mode — the kraft aesthetic
/// is a deliberate, committed look rather than a themeable one. The app
/// therefore locks to light appearance (see `NibApp`), which is why these are
/// flat constants and not dynamic colors.
public enum NibStyle {

    // MARK: - Color

    public enum Palette {
        /// Page/background of the surrounding "dossier" chrome.
        public static let kraft = Color(hex: 0xECE1C3)
        public static let kraftCard = Color(hex: 0xDFCF9F)
        public static let kraftCardLine = Color(hex: 0xCBB983)

        /// The in-app screen background.
        public static let paper = Color(hex: 0xFBF8EF)

        public static let ink = Color(hex: 0x241E15)
        public static let inkSoft = Color(hex: 0x655B41)
        public static let inkFaint = Color(hex: 0x8C815F)

        /// Brand accent — the editor's red pen.
        public static let red = Color(hex: 0xB23A1E)
        public static let redInk = Color(hex: 0x8F2E17)

        /// Grouped-list / accessory-bar surface.
        public static let surface = Color(hex: 0xF1EBD8)
        public static let divider = Color(hex: 0xE4DBC1)

        public static let green = Color(hex: 0x4CB05B)
        public static let toggleOff = Color(hex: 0xD8CBA0)

        // Keyboard-specific
        public static let keyboardBackground = Color(hex: 0xD2C6A2)
        public static let key = Color(hex: 0xFBF8EF)
        public static let keyWide = Color(hex: 0xB7AA84)
    }

    // MARK: - Typography

    /// The mockup uses Courier Prime for display type. We use the system
    /// monospaced design rather than bundling a font binary — visually close,
    /// and one less unverifiable asset. Swap to the real face in the polish pass.
    public enum Typography {
        public static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }

        /// Small uppercase section labels ("TONE PRESETS", "RECENT EDITS").
        public static let sectionLabel = Font.system(size: 11, weight: .bold, design: .monospaced)

        public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }
    }

    // MARK: - Metrics

    public enum Metrics {
        public static let cornerRadius: CGFloat = 12
        public static let buttonRadius: CGFloat = 14
        public static let screenPadding: CGFloat = 20
    }
}

// MARK: - Hex helper

extension Color {
    /// `Color(hex: 0xB23A1E)` — matches how the tokens read in the mockup CSS.
    public init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
