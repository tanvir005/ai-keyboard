import Foundation

/// Finds the word the caret is sitting at the end of.
///
/// The boundary rules are the whole problem: apostrophes and hyphens belong to
/// a word, spaces and punctuation end one, and a caret that has just passed a
/// space is not in a word at all. Getting any of those wrong means offering a
/// correction for the wrong span and replacing text the user did not type.
///
/// UIKit-free and here rather than in the keyboard, so the boundaries can be
/// tested without a device — same as `TextContextResolver`.
public enum CurrentWord {

    /// Characters that sit inside a word rather than ending it.
    private static let joiners: Set<Character> = ["'", "’", "-"]

    /// The word immediately before the caret, or nil when the caret is not at
    /// the end of one.
    ///
    /// - Parameter before: text between the start of the field and the caret.
    public static func trailing(in before: String) -> String? {
        guard let last = before.last, isWordCharacter(last) else { return nil }

        var start = before.endIndex
        while start > before.startIndex {
            let previous = before.index(before: start)
            guard isWordCharacter(before[previous]) else { break }
            start = previous
        }

        let word = String(before[start...])

        // A bare "'" or "-" is punctuation, not a word to correct.
        return word.contains(where: \.isLetter) ? word : nil
    }

    /// The finished words before the caret, in the order they were written.
    ///
    /// A word still being typed is excluded — it is the thing being predicted,
    /// not context for it. So "how are yo" gives back "how", "are".
    ///
    /// - Parameter limit: how many to return, counting back from the caret.
    public static func preceding(in before: String, limit: Int = 2) -> [String] {
        var words = before
            .split(whereSeparator: { !isWordCharacter($0) })
            .map(String.init)

        if let last = before.last, isWordCharacter(last) {
            words = Array(words.dropLast())
        }

        return Array(words.suffix(limit))
    }

    /// Whether a correction should be offered for `word` at all.
    ///
    /// Filters the cases where a spell checker is confidently unhelpful: single
    /// letters, anything with a digit, and words typed in capitals, which are
    /// usually acronyms rather than mistakes.
    public static func isCorrectable(_ word: String) -> Bool {
        guard word.count > 1 else { return false }
        guard !word.contains(where: \.isNumber) else { return false }

        let letters = word.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        guard letters != letters.uppercased() else { return false }

        return true
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || joiners.contains(character)
    }
}
