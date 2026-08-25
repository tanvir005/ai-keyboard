import UIKit
import NibKit

/// Spelling suggestions for the word the caret is in.
///
/// Backed by `UITextChecker` — the system's own dictionary — rather than a
/// bundled word list. This process runs under a tight memory ceiling and a
/// usable English dictionary is megabytes; the system already has one loaded.
///
/// Deliberately *suggestions*, not autocorrection. Nothing here replaces text
/// on its own: a wrong silent correction costs the user more than a missing
/// one, and this has no model of what they meant beyond edit distance. Tapping
/// is the whole interaction. Revisit once there is a real language model
/// behind it.
final class SpellSuggestions {

    private let checker = UITextChecker()

    /// The last word looked up and what came back.
    ///
    /// `guesses(forWordRange:)` is not cheap and this is called on every
    /// keystroke, while the word under the caret usually has not changed.
    private var cached: (word: String, results: [String])?

    private lazy var language: String = {
        let preferred = Locale.preferredLanguages.first ?? "en_US"
        let available = UITextChecker.availableLanguages
        return available.first { preferred.hasPrefix($0.prefix(2)) } ?? "en_US"
    }()

    /// Up to `limit` alternatives for the word before the caret.
    ///
    /// Empty whenever there is nothing worth offering: no word yet, a word not
    /// worth correcting, or one the checker recognises.
    func suggestions(before: String?, limit: Int = 3) -> [String] {
        guard
            let before,
            let word = CurrentWord.trailing(in: before),
            CurrentWord.isCorrectable(word)
        else { return [] }

        if let cached, cached.word == word { return cached.results }

        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: language
        )

        guard misspelled.location != NSNotFound else {
            cached = (word, [])
            return []
        }

        let guesses = checker.guesses(forWordRange: range, in: word, language: language) ?? []

        // Drop anything identical to what is already typed — offering the word
        // back to the user is noise occupying a slot a real correction wants.
        let results = guesses
            .filter { $0.caseInsensitiveCompare(word) != .orderedSame }
            .prefix(limit)

        cached = (word, Array(results))
        return Array(results)
    }
}
