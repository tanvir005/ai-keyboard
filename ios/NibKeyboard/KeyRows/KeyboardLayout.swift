import Foundation

/// A single key.
enum KeyCap: Hashable {
    case character(String)
    case shift
    case backspace
    case mode(KeyboardMode)
    case space
    case newline
    case globe
    case emoji

    /// Wide keys use the darker fill from the mockup.
    var isFunction: Bool {
        switch self {
        case .character, .space: false
        default: true
        }
    }

    /// Function keys draw a symbol rather than a glyph.
    ///
    /// `⇧`, `⌫` and `🌐` are text: they render at whatever weight and optical
    /// centre the font happens to choose, and the emoji ones come out in full
    /// colour against a monochrome board. Both stock keyboards use line
    /// symbols, and these are the same ones.
    var symbolName: String? {
        switch self {
        case .shift: "shift"
        case .backspace: "delete.left"
        case .globe: "globe"
        case .emoji: "face.smiling"
        default: nil
        }
    }

    /// Spoken by VoiceOver, which would otherwise read a symbol key as nothing
    /// at all and a glyph key as the glyph.
    var spokenLabel: String {
        switch self {
        case .character(let c): c
        case .shift: "Shift"
        case .backspace: "Delete"
        case .mode(let m): m == .letters ? "Letters" : (m == .numbers ? "Numbers" : "Symbols")
        case .space: "Space"
        case .newline: "Return"
        case .globe: "Next keyboard"
        case .emoji: "Emoji"
        }
    }

    var label: String {
        switch self {
        case .character(let c): c
        case .shift: "⇧"
        case .backspace: "⌫"
        case .mode(let m): m == .letters ? "ABC" : (m == .numbers ? "123" : "#+=")
        case .space: "space"
        case .newline: "return"
        case .globe: "🌐"
        case .emoji: "😀"
        }
    }

    /// Keys that repeat while held. Only delete — the system keyboard repeats
    /// nothing else either.
    var repeatsWhenHeld: Bool {
        if case .backspace = self { return true }
        return false
    }

    /// Relative width. 1.0 is a standard letter key.
    var widthUnits: CGFloat {
        switch self {
        case .space: 5
        case .shift, .backspace: 1.5
        case .mode, .globe, .emoji: 1.25
        case .newline: 2
        case .character: 1
        }
    }
}

enum KeyboardMode {
    case letters
    case numbers
    case symbols
}

/// US English QWERTY.
///
/// Scope for v1 is deliberately narrow — three pages, shift, backspace. No
/// swipe-typing, no custom predictive text. FEATURE_RESEARCH.md is blunt about
/// this: missing keyboard fundamentals sink ratings even when the AI is good,
/// so the fundamentals that ship must be solid before the surface grows.
enum KeyboardLayout {

    static func rows(
        for mode: KeyboardMode,
        shifted: Bool,
        needsGlobe: Bool,
        showsPeriod: Bool = false,
        showsNumberRow: Bool = false
    ) -> [[KeyCap]] {
        let rows: [[KeyCap]] = switch mode {
        case .letters: letters(shifted: shifted, needsGlobe: needsGlobe, showsPeriod: showsPeriod)
        case .numbers: numbers(needsGlobe: needsGlobe, showsPeriod: showsPeriod)
        case .symbols: symbols(needsGlobe: needsGlobe, showsPeriod: showsPeriod)
        }

        // Only above the letters. The numbers and symbols pages already have
        // digits, and a second set would be a row of duplicates.
        guard showsNumberRow, mode == .letters else { return rows }
        return [digits] + rows
    }

    private static let digits: [KeyCap] =
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { KeyCap.character($0) }

    private static func letters(shifted: Bool, needsGlobe: Bool, showsPeriod: Bool) -> [[KeyCap]] {
        let rows = [
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
            ["z", "x", "c", "v", "b", "n", "m"],
        ]
        var result = rows.map { $0.map { KeyCap.character(shifted ? $0.uppercased() : $0) } }
        result[2] = [.shift] + result[2] + [.backspace]
        result.append(bottomRow(mode: .numbers, needsGlobe: needsGlobe, showsPeriod: showsPeriod))
        return result
    }

    private static func numbers(needsGlobe: Bool, showsPeriod: Bool) -> [[KeyCap]] {
        var result: [[KeyCap]] = [
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { KeyCap.character($0) },
            ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""].map { KeyCap.character($0) },
            [".", ",", "?", "!", "'"].map { KeyCap.character($0) },
        ]
        result[2] = [.mode(.symbols)] + result[2] + [.backspace]
        result.append(bottomRow(mode: .letters, needsGlobe: needsGlobe, showsPeriod: showsPeriod))
        return result
    }

    private static func symbols(needsGlobe: Bool, showsPeriod: Bool) -> [[KeyCap]] {
        var result: [[KeyCap]] = [
            ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map { KeyCap.character($0) },
            ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"].map { KeyCap.character($0) },
            [".", ",", "?", "!", "'"].map { KeyCap.character($0) },
        ]
        result[2] = [.mode(.numbers)] + result[2] + [.backspace]
        result.append(bottomRow(mode: .letters, needsGlobe: needsGlobe, showsPeriod: showsPeriod))
        return result
    }

    /// The globe only appears when the system says it has to.
    ///
    /// On a phone with more than one keyboard installed, iOS draws its own
    /// switcher below us and `needsInputModeSwitchKey` is false — a second
    /// globe would be a duplicate spending a key's width. The emoji key takes
    /// that slot instead, which is where both stock keyboards put it and where
    /// people's thumbs go looking.
    private static func bottomRow(mode: KeyboardMode, needsGlobe: Bool, showsPeriod: Bool) -> [KeyCap] {
        var row: [KeyCap] = [.mode(mode), .emoji]
        if needsGlobe { row.append(.globe) }
        row.append(.space)
        // Between space and return, where Gboard puts it. The most common
        // punctuation there is should not cost a trip to another page.
        if showsPeriod { row.append(.character(".")) }
        row.append(.newline)
        return row
    }
}
