import Foundation

/// What usually follows what, learned from one person's own typing.
///
/// Not a language model. It is a tally: every time a word is finished, the one
/// or two words before it get a vote for it. That is enough to be genuinely
/// better than a trained general model at the things a general model cannot
/// know — a brother's name, a habitual greeting, the way *this* person opens a
/// message — and worse at everything else. The trade is the point.
///
/// Two words of context, falling back to one. One alone cannot tell
/// "how are ___" from "they are ___", and those are exactly the phrases worth
/// predicting.
public struct NextWordModel: Codable, Equatable {

    /// Context → the words seen after it, with counts.
    ///
    /// Context keys are lowercased so "How are" and "how are" are the same
    /// phrase. The *followers* keep the case they were typed in, so a learned
    /// name is suggested as `Tanvir` rather than `tanvir`.
    private var followers: [String: [String: Int]] = [:]

    public init() {}

    public init(seed: [(context: String, next: String)]) {
        for pair in seed {
            record(context: pair.context, next: pair.next, weight: 1)
        }
    }

    // MARK: - Learning

    /// Records that `next` followed `previous`.
    ///
    /// - Parameter previous: the words before it, in order. Only the last two
    ///   are used; passing more is harmless.
    /// Stands in for "nothing yet" — the start of a message.
    ///
    /// Given a context of its own so the same table can answer what a person
    /// opens with, which is a real habit and a strong one: most people begin
    /// most messages the same handful of ways. Not a word, so it can never
    /// collide with one.
    public static let sentenceStart = "\u{1}start"

    public mutating func learn(previous: [String], next: String) {
        guard Self.isLearnable(next) else { return }

        let usable = previous.filter(Self.isLearnable).suffix(2)

        // First word of the message: record it as an opener rather than
        // discarding it for having nothing before it.
        guard !usable.isEmpty else {
            record(context: Self.sentenceStart, next: next, weight: 1)
            return
        }

        // Both lengths are stored, so a phrase seen twice can answer a
        // one-word context as well as a two-word one.
        if let last = usable.last {
            record(context: last, next: next, weight: 1)
        }
        if usable.count == 2 {
            record(context: usable.joined(separator: " "), next: next, weight: 1)
        }
    }

    private mutating func record(context: String, next: String, weight: Int) {
        let key = context.lowercased()
        followers[key, default: [:]][next, default: 0] += weight
    }

    // MARK: - Predicting

    /// The most likely continuations of `previous`, most likely first.
    ///
    /// Prefers the two-word match: it is a narrower question and a better
    /// answer. Falls back to one word, which is better than nothing.
    public func predictions(after previous: [String], limit: Int = 2) -> [String] {
        let usable = previous.filter(Self.isLearnable).suffix(2)

        // An empty field is a question too, and one worth answering: the strip
        // would otherwise be blank at exactly the moment somebody is deciding
        // what to write.
        guard !usable.isEmpty else {
            return ranked(for: Self.sentenceStart, limit: limit)
        }

        if usable.count == 2 {
            let pair = ranked(for: usable.joined(separator: " "), limit: limit)
            if !pair.isEmpty { return pair }
        }

        guard let last = usable.last else { return [] }
        return ranked(for: last, limit: limit)
    }

    private func ranked(for context: String, limit: Int) -> [String] {
        guard let counts = followers[context.lowercased()] else { return [] }
        return counts
            .sorted { left, right in
                // Ties broken alphabetically so the strip does not reshuffle
                // itself between keystrokes for no visible reason.
                left.value == right.value ? left.key < right.key : left.value > right.value
            }
            .prefix(limit)
            .map(\.key)
    }

    // MARK: - Size

    public var contextCount: Int { followers.count }

    /// Drops the least-used contexts.
    ///
    /// The extension runs under a tight memory ceiling and this table only
    /// grows. Rare contexts are also the least useful ones — a phrase typed
    /// once is not a habit.
    public mutating func prune(to maximum: Int) {
        guard followers.count > maximum else { return }

        let keep = followers
            .sorted { left, right in
                let a = left.value.values.reduce(0, +)
                let b = right.value.values.reduce(0, +)
                return a == b ? left.key < right.key : a > b
            }
            .prefix(maximum)

        followers = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
    }

    public mutating func forgetEverything() {
        followers.removeAll()
    }

    // MARK: - What may be learned

    /// Whether a word is safe and useful to remember.
    ///
    /// Digits are the important exclusion: card numbers, addresses, one-time
    /// codes and phone numbers all arrive as ordinary typing in ordinary
    /// fields, and a keyboard that offers them back later is a keyboard that
    /// leaks. Secure fields are excluded too, but at the call site — this
    /// cannot see the field it was typed into.
    public static func isLearnable(_ word: String) -> Bool {
        guard !word.isEmpty, word.count <= 32 else { return false }
        guard !word.contains(where: \.isNumber) else { return false }

        // Single letters are allowed, unlike everywhere else in this codebase:
        // "I" and "a" are two of the most common words in English, and
        // excluding them silently killed every phrase that opens with one —
        // "I am", "a lot" — which is most of how people start a sentence.
        guard word.contains(where: \.isLetter) else { return false }

        return word.allSatisfy { $0.isLetter || $0 == "'" || $0 == "\u{2019}" || $0 == "-" }
    }
}
