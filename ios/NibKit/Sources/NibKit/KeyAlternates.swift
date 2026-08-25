import CoreGraphics
import Foundation

/// The characters a key offers while it is held.
///
/// Scoped to roughly what the stock en-US keyboard offers, because that is the
/// set people's fingers already expect. Deliberately not exhaustive Unicode: a
/// row wider than the keyboard has to be clipped or scrolled, and neither is
/// worth it for glyphs nobody holds a key hoping to find.
public enum KeyAlternates {

    /// The widest row the keyboard can show without running off a small phone.
    /// `rowsFitOnScreen` in the tests holds the table to it.
    public static let maximumRowLength = 9

    /// Keyed by the lowercase base character; uppercase is derived rather than
    /// listed, so the two can never drift apart.
    private static let table: [String: [String]] = [
        "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"],
        "c": ["ç", "ć", "č"],
        "d": ["ð"],
        "e": ["è", "é", "ê", "ë", "ē", "ė", "ę"],
        "g": ["ğ"],
        "i": ["î", "ï", "í", "ī", "į", "ì"],
        "l": ["ł"],
        "n": ["ñ", "ń"],
        "o": ["ô", "ö", "ò", "ó", "œ", "ø", "ō", "õ"],
        "s": ["ß", "ś", "š"],
        "u": ["û", "ü", "ù", "ú", "ū"],
        "y": ["ÿ"],
        "z": ["ž", "ź", "ż"],

        // From the numbers and symbols pages.
        "-": ["–", "—", "•"],
        "/": ["\\"],
        "$": ["₹", "¥", "€", "¢", "£", "₩"],
        "&": ["§"],
        "\"": ["“", "”", "„", "»", "«"],
        "'": ["’", "‘", "`"],
        "!": ["¡"],
        "?": ["¿"],
        "%": ["‰"],
        "=": ["≠", "≈"],
        "0": ["°"],
    ]

    /// The row shown when `character` is held: the character itself first, then
    /// its alternates.
    ///
    /// Empty when the key has none, which the caller reads as "this key does
    /// not open a row at all" — holding `q` should do nothing rather than pop
    /// an empty panel.
    public static func row(for character: String) -> [String] {
        let lowercased = character.lowercased()
        guard let alternates = table[lowercased], !alternates.isEmpty else { return [] }

        guard character != lowercased else { return [character] + alternates }

        // Uppercase the alternates to match the key, dropping any whose capital
        // form is not a single character — ß uppercases to "SS", which is not a
        // glyph anyone is reaching for on a held key.
        let capitals = alternates
            .map { $0.uppercased() }
            .filter { $0.count == 1 }

        return [character] + capitals
    }

    /// Which item in the row the finger is currently over.
    ///
    /// Kept here as plain arithmetic rather than in the view for the same
    /// reason `TextContextResolver` is — it is the part that is easy to get
    /// subtly wrong and expensive to debug on a device only.
    ///
    /// - Parameters:
    ///   - x: the touch position, in the same space as `rowLeft`.
    ///   - rowLeft: the left edge of the first item.
    ///   - itemWidth: the width of one item.
    ///   - count: how many items the row holds.
    /// - Returns: an index clamped into the row, so a finger dragged past
    ///   either end holds the outermost item rather than selecting nothing.
    public static func index(
        forX x: CGFloat,
        rowLeft: CGFloat,
        itemWidth: CGFloat,
        count: Int
    ) -> Int {
        guard count > 0, itemWidth > 0 else { return 0 }
        let raw = Int(((x - rowLeft) / itemWidth).rounded(.down))
        return min(max(raw, 0), count - 1)
    }

    /// Whether a key opens its row leftward.
    ///
    /// Keys past the halfway mark do, so the row grows toward the middle of the
    /// board rather than into the edge it is already near.
    public static func opensLeftward(keyCenterX: CGFloat, boardWidth: CGFloat) -> Bool {
        keyCenterX > boardWidth / 2
    }

    /// Where the row's left edge sits, in the board's coordinate space.
    ///
    /// The point of this is to keep the *base* glyph over the key that opened
    /// the row, so the highlighted item starts under the finger. Centring the
    /// row and clamping it — the obvious approach — puts the base glyph at
    /// whichever end got pushed away, which on a right-hand key is nowhere near
    /// the thumb that opened it.
    ///
    /// The row is then pushed back inside the board, because an item hanging
    /// off the edge is clipped, and a finger cannot drag to something it cannot
    /// see.
    public static func rowLeft(
        keyCenterX: CGFloat,
        keyWidth: CGFloat,
        rowWidth: CGFloat,
        boardWidth: CGFloat,
        boardInset: CGFloat,
        padding: CGFloat,
        opensLeftward: Bool
    ) -> CGFloat {
        let desired = opensLeftward
            ? keyCenterX + keyWidth / 2 + padding - rowWidth
            : keyCenterX - keyWidth / 2 - padding

        let lowerBound = boardInset
        let upperBound = boardWidth - boardInset - rowWidth
        guard upperBound > lowerBound else { return lowerBound }
        return min(max(desired, lowerBound), upperBound)
    }

    /// Every base character that opens a row. Test-facing.
    public static var keysWithAlternates: [String] {
        table.keys.sorted()
    }
}
