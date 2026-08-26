import SwiftUI

// The package builds for macOS purely so `swift test` runs without a simulator,
// and there is no UIKit there. Guarded rather than moved out of NibKit: the
// tokens are the one place a colour should be defined, and splitting them by
// platform would put half the palette somewhere else.
#if canImport(UIKit)
import UIKit
#endif

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

        // Keyboard-specific: the stock iOS palette rather than the kraft one.
        //
        // The board sits directly above a strip the system draws and colours
        // itself — the globe and dictation bar — which cannot be restyled from
        // an extension. Kraft above system grey read as two keyboards stacked,
        // and the seam was the first thing the eye went to. Matching the system
        // makes that seam disappear.
        //
        // The cost is real: the surface people spend the most time looking at
        // no longer carries the kraft identity, which now lives in the app and
        // in the accent. That is the trade, made deliberately.
        //
        // Named from the system palette rather than mixed here. A hand-picked
        // hex cannot stay matched: the first attempt was a bluish grey against
        // the bar's neutral one and the seam was plain on a device. Apple has
        // also changed these greys between releases, so a frozen value drifts
        // even if it starts right. Naming the colour tracks whatever the system
        // is using today.
        public static let keyboardBackground = systemGray5

        /// Behind the tool row and the suggestion strip — the same grey as the
        /// board, so the whole keyboard reads as one surface.
        public static let keyboardAccessory = systemGray5

        public static let key = systemKey
        public static let keyWide = systemGray4

        /// Key caps and the glyphs on them. Not `ink`: the kraft brown was
        /// mixed for paper, and on a white key against system grey it reads as
        /// a smudge rather than as type.
        public static let keyLabel = systemLabel

        /// Text and glyphs sitting on the red accent. Cream in both appearances
        /// — the accent itself does not change lightness enough to flip it.
        public static let onAccent = Color(hex: 0xFBF3E8)

        /// Flat fill behind the onboarding illustrations.
        public static let illustration = Color.adaptive(light: 0xEFE6CC, dark: 0x2A241B)

        // MARK: - Borrowed from the system
        //
        // The fallbacks are only reached in the headless macOS test build,
        // where nothing is drawn. They are Apple's published values, kept so
        // the file still reads as a palette rather than a set of holes.

        private static let systemGray4: Color = {
            #if canImport(UIKit)
            Color(UIColor.systemGray4)
            #else
            Color.adaptive(light: 0xD1D1D6, dark: 0x3A3A3C)
            #endif
        }()

        private static let systemGray5: Color = {
            #if canImport(UIKit)
            Color(UIColor.systemGray5)
            #else
            Color.adaptive(light: 0xE5E5EA, dark: 0x2C2C2E)
            #endif
        }()

        /// White in the light, and a grey *lighter* than the board in the dark
        /// — keys read as raised in both, which is the one relationship the
        /// system's own keyboard never inverts.
        private static let systemKey: Color = {
            #if canImport(UIKit)
            Color(UIColor { $0.userInterfaceStyle == .dark ? .systemGray3 : .white })
            #else
            Color.adaptive(light: 0xFFFFFF, dark: 0x48484A)
            #endif
        }()

        private static let systemLabel: Color = {
            #if canImport(UIKit)
            Color(UIColor.label)
            #else
            Color.adaptive(light: 0x000000, dark: 0xFFFFFF)
            #endif
        }()
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
        #if canImport(UIKit)
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        // Only reachable in the headless test build, which never renders.
        Color(hex: light)
        #endif
    }
}

#if canImport(UIKit)
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
#endif
