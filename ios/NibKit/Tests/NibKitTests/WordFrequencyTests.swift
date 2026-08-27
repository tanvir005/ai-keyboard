import XCTest
@testable import NibKit

/// Ranking is the whole reason this list exists — the system checker returns
/// candidates in an order nobody would choose. These pin the ordering rules
/// rather than the contents, which will drift as the list is tuned.
final class WordFrequencyTests: XCTestCase {

    func testTheMostOrdinaryWordsRankHighest() {
        XCTAssertEqual(WordFrequency.rank(of: "the"), 0)
        XCTAssertNotNil(WordFrequency.rank(of: "hello"))
        XCTAssertNotNil(WordFrequency.rank(of: "help"))
    }

    func testRankIsCaseInsensitive() {
        XCTAssertEqual(WordFrequency.rank(of: "The"), WordFrequency.rank(of: "the"))
        XCTAssertEqual(WordFrequency.rank(of: "HELLO"), WordFrequency.rank(of: "hello"))
    }

    func testUnknownWordsHaveNoRank() {
        XCTAssertNil(WordFrequency.rank(of: "helicoid"))
        XCTAssertNil(WordFrequency.rank(of: "zzzzz"))
    }

    /// The case the list was added for: an ordinary word buried behind an
    /// obscure one that happens to share a prefix.
    func testOrdinaryWordsSortAheadOfObscureOnes() {
        let ranked = WordFrequency.ranked(["helicoid", "helical", "hello", "help"])
        XCTAssertEqual(Array(ranked.prefix(2)).sorted(), ["hello", "help"])
    }

    /// The list has no opinion about words it does not know, so it must not
    /// invent one — the checker's own order is better than alphabetical there.
    func testUnknownWordsKeepTheOrderTheyArrivedIn() {
        let input = ["zebulon", "aardvarkish", "myriad"]
        XCTAssertEqual(WordFrequency.ranked(input), input)
    }

    func testKnownWordsComeBeforeUnknownOnes() {
        let ranked = WordFrequency.ranked(["aardvarkish", "the"])
        XCTAssertEqual(ranked.first, "the")
    }

    func testRankingKeepsEveryCandidate() {
        let input = ["helicoid", "hello", "zzz", "help"]
        XCTAssertEqual(WordFrequency.ranked(input).sorted(), input.sorted())
    }

    func testEmptyInputIsSafe() {
        XCTAssertTrue(WordFrequency.ranked([]).isEmpty)
    }

    // MARK: - Matching a prefix

    /// The case it exists for: one letter, where the system checker returns
    /// thousands of words in no useful order.
    func testASingleLetterStillOffersSomething() {
        XCTAssertFalse(WordFrequency.matching(prefix: "h").isEmpty)
        XCTAssertFalse(WordFrequency.matching(prefix: "t").isEmpty)
        XCTAssertFalse(WordFrequency.matching(prefix: "a").isEmpty)
    }

    func testMatchesActuallyStartWithThePrefix() {
        for word in WordFrequency.matching(prefix: "he", limit: 5) {
            XCTAssertTrue(word.hasPrefix("he"), "\(word) does not start with he")
        }
    }

    func testTheMostCommonMatchComesFirst() {
        // "the" outranks every other word beginning with "th".
        XCTAssertEqual(WordFrequency.matching(prefix: "th", limit: 1), ["the"])
    }

    func testMatchingIsCaseInsensitive() {
        XCTAssertEqual(
            WordFrequency.matching(prefix: "TH", limit: 2),
            WordFrequency.matching(prefix: "th", limit: 2)
        )
    }

    /// Offering the word back to somebody who has just typed it is a wasted
    /// slot, not a suggestion.
    func testAnExactMatchIsNotOfferedBack() {
        XCTAssertFalse(WordFrequency.matching(prefix: "the", limit: 5).contains("the"))
    }

    func testLimitIsRespected() {
        XCTAssertLessThanOrEqual(WordFrequency.matching(prefix: "a", limit: 2).count, 2)
    }

    func testNothingMatchesNothing() {
        XCTAssertTrue(WordFrequency.matching(prefix: "").isEmpty)
        XCTAssertTrue(WordFrequency.matching(prefix: "zzzz").isEmpty)
    }

    // MARK: - The list itself

    func testListHasNoDuplicates() {
        let common = WordFrequency.common
        XCTAssertEqual(Set(common).count, common.count, "the list repeats a word")
    }

    func testListIsAllLowercaseLetters() {
        for word in WordFrequency.common {
            XCTAssertEqual(word, word.lowercased(), "\(word) is not lowercase")
            XCTAssertTrue(
                word.allSatisfy(\.isLetter),
                "\(word) contains something other than letters"
            )
        }
    }

    /// Small enough for a memory-constrained extension, big enough to be worth
    /// consulting. If either bound trips, the list needs a deliberate decision
    /// rather than a quiet drift.
    func testListStaysInItsIntendedSize() {
        XCTAssertGreaterThan(WordFrequency.common.count, 500)
        XCTAssertLessThan(WordFrequency.common.count, 4_000)
    }
}
