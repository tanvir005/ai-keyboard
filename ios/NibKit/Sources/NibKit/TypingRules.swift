import CoreGraphics
import Foundation

/// The small typing conventions people never notice until they are missing.
///
/// Pure functions, here rather than in the keyboard, so they can be tested
/// without a device — the same reason `TextContextResolver` lives in this
/// package. Each one is a rule about what the *document* looks like, which is
/// exactly the kind of thing that is fiddly to reason about and cheap to test.
public enum TypingRules {

    // MARK: - Double space

    /// Whether a second space should become a full stop.
    ///
    /// Both stock keyboards do this, and fingers expect it. The rule is
    /// narrower than "the last character is a space": a space is only promoted
    /// when it actually ends a word, so leading indentation and deliberate
    /// double spacing are left alone, and a sentence is never given two full
    /// stops.
    ///
    /// - Parameter before: the text between the start of the field and the
    ///   caret. Pass `documentContextBeforeInput` straight in.
    public static func shouldPromoteSpaceToSentenceBreak(before: String) -> Bool {
        guard before.hasSuffix(" ") else { return false }

        let withoutSpace = before.dropLast()
        guard let preceding = withoutSpace.last else { return false } // " " alone

        if preceding.isWhitespace { return false }        // "word  " — deliberate
        if ".!?,:;".contains(preceding) { return false }  // "word. " — already ended
        return true
    }

    // MARK: - Releasing a key

    /// Whether a touch released at `location` should still count as a press of
    /// a key of `size`.
    ///
    /// A release away from the key cancels it, which is what both stock
    /// keyboards do and what the hand expects — sliding off is how you take a
    /// keystroke back. The slop is what stops an ordinary thumb roll from
    /// cancelling a keystroke that was meant, so it is deliberately generous
    /// relative to the gaps between keys.
    public static func releaseCommitsKey(
        location: CGPoint,
        size: CGSize,
        slop: CGFloat = 8
    ) -> Bool {
        location.x >= -slop
            && location.x <= size.width + slop
            && location.y >= -slop
            && location.y <= size.height + slop
    }
}
