import UIKit
import NibKit

/// What the strip offers for the word being typed.
///
/// `typed` is always what is actually in the document, and always the first
/// slot — tapping it is how you keep a word the dictionary does not know.
/// `candidates` are the alternatives, best first, and the best one goes in the
/// middle where the thumb and the eye already are.
struct WordSuggestions: Equatable {
    var typed: String = ""
    var candidates: [String] = []

    var isEmpty: Bool { candidates.isEmpty }
}

/// Corrections and completions for the word the caret is in.
///
/// Backed by `UITextChecker` — the system's own dictionary — rather than a
/// bundled word list. This process runs under a tight memory ceiling, a usable
/// English dictionary is megabytes, and the system already has one loaded.
///
/// Two different questions, depending on the word:
///
/// - the checker does not recognise it → offer **corrections** (`guesses`)
/// - it does, or it is the start of longer words → offer **completions**
///
/// The second is what makes the strip useful *while* typing rather than only
/// after a mistake. `hel` is not misspelled; it is unfinished.
final class SpellSuggestions {

    /// Below this, the candidate list is enormous and says nothing — `he` is
    /// the opening of thousands of words. Three letters is roughly where a
    /// prefix starts being a guess rather than an alphabet.
    private static let minimumPrefix = 3

    private let checker = UITextChecker()

    /// The last word looked up and what came back.
    ///
    /// Both checker calls are expensive and this runs on every keystroke, while
    /// the word under the caret usually has not changed.
    private var cached: (word: String, result: WordSuggestions)?

    /// A word the user kept by tapping it, suppressed until they move on — so
    /// dismissing a suggestion does not simply bring it back next keystroke.
    private var kept: String?

    private lazy var language: String = {
        let preferred = Locale.preferredLanguages.first ?? "en_US"
        let available = UITextChecker.availableLanguages
        return available.first { preferred.hasPrefix($0.prefix(2)) } ?? "en_US"
    }()

    /// The user tapped their own word: keep it now, and teach the system so it
    /// stops being flagged at all.
    ///
    /// This is what makes the strip bearable for names, brands and transliterated
    /// words — otherwise every one of them is offered a correction every time it
    /// is typed, forever.
    func keep(_ word: String) {
        kept = word
        cached = nil
        UITextChecker.learnWord(word)
    }

    func suggestions(before: String?, limit: Int = 2) -> WordSuggestions {
        guard
            let before,
            let word = CurrentWord.trailing(in: before),
            CurrentWord.isCorrectable(word),
            word.count >= Self.minimumPrefix
        else {
            kept = nil
            return WordSuggestions()
        }

        if word == kept { return WordSuggestions() }
        if let cached, cached.word == word { return cached.result }

        let range = NSRange(location: 0, length: word.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: language
        )

        let raw: [String] = misspelled.location == NSNotFound
            ? checker.completions(forPartialWordRange: range, in: word, language: language) ?? []
            : checker.guesses(forWordRange: range, in: word, language: language) ?? []

        // The checker returns these unranked, so "hel" can lead with "helicoid".
        // Ordering by how ordinary each word is, before trimming to two slots,
        // is the difference between a useful strip and a curious one.
        let candidates = WordFrequency
            .ranked(raw)
            .filter { $0.caseInsensitiveCompare(word) != .orderedSame }
            .map { matchCase(of: word, in: $0) }
            .prefix(limit)

        let result = WordSuggestions(typed: word, candidates: Array(candidates))
        cached = (word, result)
        return result
    }

    /// Carries the typed word's capitalisation onto the suggestion.
    ///
    /// The dictionary is lowercase, so without this typing `Hel` at the start of
    /// a sentence offers `hello` — and taking it undoes the capital the keyboard
    /// just auto-shifted in.
    private func matchCase(of typed: String, in candidate: String) -> String {
        guard let first = typed.first, first.isUppercase else { return candidate }

        // All caps in, all caps out; otherwise just the leading letter.
        if typed.count > 1, typed == typed.uppercased() {
            return candidate.uppercased()
        }
        return candidate.prefix(1).uppercased() + candidate.dropFirst()
    }
}
