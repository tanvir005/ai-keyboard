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

    /// Wide keys use the darker fill from the mockup.
    var isFunction: Bool {
        switch self {
        case .character, .space: false
        default: true
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
        }
    }

    /// Relative width. 1.0 is a standard letter key.
    var widthUnits: CGFloat {
        switch self {
        case .space: 5
        case .shift, .backspace: 1.5
        case .mode, .globe: 1.25
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

    static func rows(for mode: KeyboardMode, shifted: Bool) -> [[KeyCap]] {
        switch mode {
        case .letters: letters(shifted: shifted)
        case .numbers: numbers()
        case .symbols: symbols()
        }
    }

    private static func letters(shifted: Bool) -> [[KeyCap]] {
        let rows = [
            ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
            ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
            ["z", "x", "c", "v", "b", "n", "m"],
        ]
        var result = rows.map { $0.map { KeyCap.character(shifted ? $0.uppercased() : $0) } }
        result[2] = [.shift] + result[2] + [.backspace]
        result.append(bottomRow(mode: .numbers))
        return result
    }

    private static func numbers() -> [[KeyCap]] {
        var result: [[KeyCap]] = [
            ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { KeyCap.character($0) },
            ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""].map { KeyCap.character($0) },
            [".", ",", "?", "!", "'"].map { KeyCap.character($0) },
        ]
        result[2] = [.mode(.symbols)] + result[2] + [.backspace]
        result.append(bottomRow(mode: .letters))
        return result
    }

    private static func symbols() -> [[KeyCap]] {
        var result: [[KeyCap]] = [
            ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map { KeyCap.character($0) },
            ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"].map { KeyCap.character($0) },
            [".", ",", "?", "!", "'"].map { KeyCap.character($0) },
        ]
        result[2] = [.mode(.numbers)] + result[2] + [.backspace]
        result.append(bottomRow(mode: .letters))
        return result
    }

    private static func bottomRow(mode: KeyboardMode) -> [KeyCap] {
        [.mode(mode), .globe, .space, .newline]
    }
}
