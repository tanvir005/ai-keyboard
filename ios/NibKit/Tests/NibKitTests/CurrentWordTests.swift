import XCTest
@testable import NibKit

/// Word boundaries decide which span a correction replaces. Getting one wrong
/// eats text the user typed on purpose, so they are worth pinning down here
/// rather than discovering in a chat thread.
final class CurrentWordTests: XCTestCase {

    // MARK: - Finding the word

    func testFindsTheWordBeforeTheCaret() {
        XCTAssertEqual(CurrentWord.trailing(in: "hello"), "hello")
        XCTAssertEqual(CurrentWord.trailing(in: "say hello"), "hello")
        XCTAssertEqual(CurrentWord.trailing(in: "one two three"), "three")
    }

    /// The caret has moved past the word, so there is nothing to correct yet.
    func testNoWordAfterASpaceOrPunctuation() {
        XCTAssertNil(CurrentWord.trailing(in: "hello "))
        XCTAssertNil(CurrentWord.trailing(in: "hello."))
        XCTAssertNil(CurrentWord.trailing(in: "hello,"))
        XCTAssertNil(CurrentWord.trailing(in: "hello\n"))
        XCTAssertNil(CurrentWord.trailing(in: ""))
    }

    func testApostrophesAndHyphensStayInsideTheWord() {
        XCTAssertEqual(CurrentWord.trailing(in: "don't"), "don't")
        XCTAssertEqual(CurrentWord.trailing(in: "it’s"), "it’s")
        XCTAssertEqual(CurrentWord.trailing(in: "well-known"), "well-known")
        XCTAssertEqual(CurrentWord.trailing(in: "say don't"), "don't")
    }

    /// Punctuation on its own is not a word, however word-like the character.
    func testBareJoinersAreNotWords() {
        XCTAssertNil(CurrentWord.trailing(in: "-"))
        XCTAssertNil(CurrentWord.trailing(in: "say '"))
        XCTAssertNil(CurrentWord.trailing(in: "a --"))
    }

    func testStopsAtTheStartOfTheField() {
        XCTAssertEqual(CurrentWord.trailing(in: "a"), "a")
    }

    /// The returned span must be an exact suffix, or replacing it corrupts the
    /// text around it. Same invariant `TextContextResolver` holds to.
    func testTheWordIsAlwaysAnExactSuffix() {
        let inputs = [
            "hello", "say hello", "don't", "well-known", "a", "Mixed Case Word",
            "emoji 👨‍👩‍👧‍👦 word", "trailing", "multi\nline text",
        ]
        for input in inputs {
            guard let word = CurrentWord.trailing(in: input) else { continue }
            XCTAssertTrue(input.hasSuffix(word), "\(word) is not a suffix of \(input)")
        }
    }

    // MARK: - Context for prediction

    func testFindsTheFinishedWordsBehindTheCaret() {
        XCTAssertEqual(CurrentWord.preceding(in: "how are you "), ["are", "you"])
        XCTAssertEqual(CurrentWord.preceding(in: "hello "), ["hello"])
        XCTAssertEqual(CurrentWord.preceding(in: "one two three ", limit: 3), ["one", "two", "three"])
    }

    /// A half-typed word is what we are predicting, not context for it.
    func testTheWordStillBeingTypedIsNotContext() {
        XCTAssertEqual(CurrentWord.preceding(in: "how are yo"), ["how", "are"])
        XCTAssertEqual(CurrentWord.preceding(in: "hello wor"), ["hello"])
    }

    func testPunctuationEndsAWordForContextToo() {
        XCTAssertEqual(CurrentWord.preceding(in: "hello, "), ["hello"])
        XCTAssertEqual(CurrentWord.preceding(in: "done. "), ["done"])
    }

    func testNoContextAtTheStartOfAField() {
        XCTAssertTrue(CurrentWord.preceding(in: "").isEmpty)
        XCTAssertTrue(CurrentWord.preceding(in: "   ").isEmpty)
        XCTAssertTrue(CurrentWord.preceding(in: "hel").isEmpty)
    }

    // MARK: - Whether it is worth correcting

    func testOrdinaryWordsAreCorrectable() {
        XCTAssertTrue(CurrentWord.isCorrectable("teh"))
        XCTAssertTrue(CurrentWord.isCorrectable("hello"))
        XCTAssertTrue(CurrentWord.isCorrectable("Hello"))
        XCTAssertTrue(CurrentWord.isCorrectable("don't"))
    }

    /// A single letter has too many equally-good "corrections" to offer any.
    func testSingleLettersAreNotCorrectable() {
        XCTAssertFalse(CurrentWord.isCorrectable("a"))
        XCTAssertFalse(CurrentWord.isCorrectable("I"))
    }

    /// Capitals are usually acronyms, and anything with a digit is usually a
    /// code or a model number. Correcting either is confidently unhelpful.
    func testAcronymsAndCodesAreLeftAlone() {
        XCTAssertFalse(CurrentWord.isCorrectable("NASA"))
        XCTAssertFalse(CurrentWord.isCorrectable("HTTP"))
        XCTAssertFalse(CurrentWord.isCorrectable("a1b2"))
        XCTAssertFalse(CurrentWord.isCorrectable("iOS17"))
    }
}
