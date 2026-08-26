import SwiftUI
import UIKit

/// Design tokens lifted from the concept mockup (docs/screens/nib-concept.html).
///
/// Note on appearance: the mockup renders every phone screen on constant
/// `#FBF8EF` paper stock. That was carried into the app as a committed look and
/// a forced light appearance, which is no longer true: every token below
/// resolves against the current appearance, and the app follows the phone.
public enum NibStyle {

    // MARK: - Color

    /// Every token resolves against the current appearance.
    ///
    /// The dark side is not an inversion. Kraft paper has no dark equivalent,
    /// so what carries over is the *relationship* between the values — warm
    /// rather than neutral greys, the editor's red still the only saturated
    /// thing on screen, and keys lighter than the board they sit on, which is
    /// the one place dark mode flips the light layout's order.
    public enum Palette {
        /// Page/background of the surrounding "dossier" chrome.
        public static let kraft = Color.adaptive(light: 0xECE1C3, dark: 0x211C15)
        public static let kraftCard = Color.adaptive(light: 0xDFCF9F, dark: 0x2C261D)
        public static let kraftCardLine = Color.adaptive(light: 0xCBB983, dark: 0x3E3628)

        /// The in-app screen background.
        public static let paper = Color.adaptive(light: 0xFBF8EF, dark: 0x171410)

        public static let ink = Color.adaptive(light: 0x241E15, dark: 0xF3EDE0)
        public static let inkSoft = Color.adaptive(light: 0x655B41, dark: 0xB4A891)
        public static let inkFaint = Color.adaptive(light: 0x8C815F, dark: 0x877C68)

        /// Brand accent — the editor's red pen. Lifted in the dark, where the
        /// print red goes muddy against a dark ground.
        public static let red = Color.adaptive(light: 0xB23A1E, dark: 0xD65A38)
        public static let redInk = Color.adaptive(light: 0x8F2E17, dark: 0xE87A5A)

        /// Grouped-list / accessory-bar surface.
        public static let surface = Color.adaptive(light: 0xF1EBD8, dark: 0x211C15)
        public static let divider = Color.adaptive(light: 0xE4DBC1, dark: 0x3A3327)

        public static let green = Color.adaptive(light: 0x4CB05B, dark: 0x5FBF6E)
        public static let toggleOff = Color.adaptive(light: 0xD8CBA0, dark: 0x494133)

        // Keyboard-specific.
        //
        // Note the inversion: in the light board the keys are *lighter* than the
        // board and the function keys darker. In the dark board the keys are
        // lighter than the board too — so function keys become darker again
        // rather than the whole relationship flipping. Keys read as raised in
        // both, which is the point.
        public static let keyboardBackground = Color.adaptive(light: 0xD2C6A2, dark: 0x120F0B)
        public static let key = Color.adaptive(light: 0xFBF8EF, dark: 0x3B342A)
        public static let keyWide = Color.adaptive(light: 0xB7AA84, dark: 0x262119)

        /// Text and glyphs sitting on the red accent. Cream in both appearances
        /// — the accent itself does not change lightness enough to flip it.
        public static let onAccent = Color(hex: 0xFBF3E8)

        /// Flat fill behind the onboarding illustrations.
        public static let illustration = Color.adaptive(light: 0xEFE6CC, dark: 0x2A241B)
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

    /// A token that resolves against the current appearance.
    ///
    /// Backed by `UIColor`'s trait-aware initialiser rather than by reading the
    /// colour scheme in each view: a token has to resolve correctly inside the
    /// keyboard extension too, where there is no environment of ours to read.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
