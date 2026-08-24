import XCTest
@testable import NibKit

/// These cover the one piece of extension logic that is both easy to get subtly
/// wrong and expensive to debug only on a device. Run with `swift test`.
final class TextContextResolverTests: XCTestCase {

    // MARK: - The invariant everything else depends on

    /// If this ever breaks, tap-to-insert corrupts the user's text: we would
    /// delete a different number of characters than we actually sent.
    func testScopeIsAlwaysAnExactSuffixOfTheInput() {
        let inputs = [
            "Hello world",
            "Hello. World",
            "Line one\nLine two",
            "   leading whitespace",
            "trailing space ",
            "Multiple. Sentences. Here.",
            "no terminator at all just words",
            String(repeating: "long ", count: 500),
            "café naïve 👨‍👩‍👧‍👦 emoji",
        ]

        for input in inputs {
            let scope = TextContextResolver.resolve(before: input)
            XCTAssertTrue(
                input.hasSuffix(scope.text),
                "Scope \"\(scope.text)\" is not a suffix of \"\(input)\""
            )
            XCTAssertEqual(
                scope.deleteCount, scope.text.count,
                "deleteCount must equal the Character count of the scope"
            )
        }
    }

    // MARK: - Boundaries

    func testEmptyAndNilInputProduceEmptyScope() {
        XCTAssertEqual(TextContextResolver.resolve(before: nil), .empty)
        XCTAssertEqual(TextContextResolver.resolve(before: ""), .empty)
    }

    func testWholeTextUsedWhenThereIsNoBoundary() {
        let scope = TextContextResolver.resolve(before: "just one run of words")
        XCTAssertEqual(scope.text, "just one run of words")
    }

    func testSplitsAtNearestSentenceEnd() {
        let scope = TextContextResolver.resolve(before: "Hello there. World again")
        XCTAssertEqual(scope.text, "World again")
        XCTAssertEqual(scope.deleteCount, 11)
    }

    func testParagraphBreakTakesPrecedenceOverSentenceEnd() {
        let scope = TextContextResolver.resolve(before: "First. Second.\nThird sentence")
        XCTAssertEqual(scope.text, "Third sentence")
    }

    func testUsesNearestBoundaryNotTheFirst() {
        let scope = TextContextResolver.resolve(before: "One. Two. Three.  Final bit")
        XCTAssertEqual(scope.text, "Final bit")
    }

    func testDecimalsAndDomainsDoNotSplit() {
        // No whitespace after the "." — must not be treated as a sentence end.
        let scope = TextContextResolver.resolve(before: "the price is 3.5 dollars")
        XCTAssertEqual(scope.text, "the price is 3.5 dollars")

        let domain = TextContextResolver.resolve(before: "go to nib.app now")
        XCTAssertEqual(domain.text, "go to nib.app now")
    }

    func testLeadingWhitespaceIsDropped() {
        let scope = TextContextResolver.resolve(before: "Done.     next words")
        XCTAssertEqual(scope.text, "next words")
    }

    func testAllWhitespaceAfterBoundaryYieldsEmptyScope() {
        let scope = TextContextResolver.resolve(before: "Finished.   ")
        XCTAssertEqual(scope.text, "")
        XCTAssertEqual(scope.deleteCount, 0)
        XCTAssertTrue(scope.isEmpty)
    }

    // MARK: - Grapheme correctness

    /// A family emoji is one Character but many UTF-16 code units. Counting
    /// code units here would delete far too much.
    func testEmojiCountsAsASingleDeleteBackward() {
        let family = "👨‍👩‍👧‍👦"
        XCTAssertGreaterThan(family.utf16.count, 1, "precondition: multi-unit grapheme")

        let scope = TextContextResolver.resolve(before: "hi \(family)")
        XCTAssertEqual(scope.text, "hi \(family)")
        XCTAssertEqual(scope.deleteCount, 4) // h, i, space, family
    }

    func testCombiningMarksCountAsSingleCharacters() {
        let scope = TextContextResolver.resolve(before: "café")
        XCTAssertEqual(scope.deleteCount, 4)
    }

    // MARK: - Read-full-draft toggle

    func testDefaultScopeIsCappedToNearbyLimit() {
        let long = String(repeating: "a", count: 2_000)
        let scope = TextContextResolver.resolve(before: long, readFullDraft: false)
        XCTAssertEqual(scope.deleteCount, TextContextResolver.Limits.nearby)
    }

    func testFullDraftWidensTheCap() {
        let long = String(repeating: "a", count: 2_000)
        let scope = TextContextResolver.resolve(before: long, readFullDraft: true)
        XCTAssertEqual(scope.deleteCount, 2_000)
    }

    /// The privacy promise: with the toggle off, text after the cursor is never
    /// collected, let alone sent.
    func testTrailingContextIsWithheldUnlessFullDraftIsOn() {
        let off = TextContextResolver.resolve(
            before: "hello", after: "world", readFullDraft: false
        )
        XCTAssertNil(off.after)

        let on = TextContextResolver.resolve(
            before: "hello", after: "world", readFullDraft: true
        )
        XCTAssertEqual(on.after, "world")
    }

    func testTrailingContextIsCapped() {
        let long = String(repeating: "b", count: 5_000)
        let scope = TextContextResolver.resolve(
            before: "hello", after: long, readFullDraft: true
        )
        XCTAssertEqual(scope.after?.count, TextContextResolver.Limits.trailing)
    }
}
