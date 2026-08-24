import Foundation

/// The span of text Nib will send to the AI and, on insert, replace.
public struct TextScope: Equatable, Sendable {
    /// The text to operate on. **Always an exact suffix of the text before the
    /// cursor** — that invariant is what makes `deleteCount` safe to act on.
    public let text: String

    /// Number of `deleteBackward()` calls needed to remove exactly `text`.
    ///
    /// This counts Swift `Character`s (extended grapheme clusters), which is
    /// what `deleteBackward()` removes per call. Counting UTF-16 code units
    /// here would over-delete and tear apart emoji and combining marks.
    public let deleteCount: Int

    /// Text following the cursor. Populated only when the user has enabled
    /// "Read full draft" — otherwise `nil`, and never sent.
    public let after: String?

    public var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public init(text: String, deleteCount: Int, after: String?) {
        self.text = text
        self.deleteCount = deleteCount
        self.after = after
    }

    public static let empty = TextScope(text: "", deleteCount: 0, after: nil)
}

/// Decides *what text Nib is allowed to look at*.
///
/// ## Why this exists
/// `UITextDocumentProxy` never exposes `selectedTextRange`. A keyboard
/// extension genuinely cannot know what the user has selected — this is a
/// permanent iOS platform limitation, not something to engineer around. So Nib
/// never claims to know a selection. It treats the cursor as the boundary,
/// operates on the text immediately before it, and says so in the UI.
///
/// Because the scope is always an exact suffix of the text before the cursor,
/// replacing it needs no selection API at all: delete `deleteCount` characters
/// backward, then insert the suggestion.
///
/// Deliberately free of UIKit so it can be tested with `swift test`.
public enum TextContextResolver {

    public enum Limits {
        /// Default reach: roughly a paragraph. Applies when "Read full draft" is off.
        public static let nearby = 600
        /// Reach when the user has explicitly enabled "Read full draft".
        public static let fullDraft = 4_000
        /// How much text after the cursor to include, full-draft mode only.
        public static let trailing = 1_000
    }

    /// - Parameters:
    ///   - before: `documentContextBeforeInput` from the text document proxy.
    ///   - after: `documentContextAfterInput`. Ignored unless `readFullDraft`.
    ///   - readFullDraft: the user's Settings toggle. Off by default — this is
    ///     the privacy promise from the Settings screen made literal.
    public static func resolve(
        before: String?,
        after: String? = nil,
        readFullDraft: Bool = false
    ) -> TextScope {
        let source = before ?? ""
        guard !source.isEmpty else { return .empty }

        let cap = readFullDraft ? Limits.fullDraft : Limits.nearby

        // Taking a suffix keeps the exact-suffix invariant intact.
        var chars = Array(source)
        if chars.count > cap {
            chars = Array(chars.suffix(cap))
        }

        let start = boundaryIndex(in: chars)
        let scopeChars = Array(chars[start...])

        let trailing: String? = {
            guard readFullDraft, let after, !after.isEmpty else { return nil }
            return String(after.prefix(Limits.trailing))
        }()

        return TextScope(
            text: String(scopeChars),
            deleteCount: scopeChars.count,
            after: trailing
        )
    }

    /// Finds where the operable span begins: the nearest paragraph break, else
    /// the nearest sentence end, else the start of the capped window.
    private static func boundaryIndex(in chars: [Character]) -> Int {
        guard !chars.isEmpty else { return 0 }

        var boundary = 0

        if let newline = chars.lastIndex(where: { $0.isNewline }) {
            // A paragraph break is the strongest signal — prefer it outright.
            boundary = newline + 1
        } else {
            // Otherwise walk back to the nearest sentence terminator that is
            // actually followed by whitespace, so decimals like "3.5" and
            // domains like "nib.app" don't split. Abbreviations followed by a
            // space ("e.g. ") still split — accepted: the cost is a slightly
            // short scope, not a corrupted edit, since the suffix invariant holds.
            var i = chars.count - 1
            while i > 0 {
                if chars[i].isWhitespace, isTerminator(chars[i - 1]) {
                    boundary = i + 1
                    break
                }
                i -= 1
            }
        }

        // Drop leading whitespace — a shorter suffix is still a suffix.
        while boundary < chars.count, chars[boundary].isWhitespace {
            boundary += 1
        }

        return boundary
    }

    private static func isTerminator(_ c: Character) -> Bool {
        c == "." || c == "!" || c == "?"
    }
}
