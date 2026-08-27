import XCTest
@testable import NibKit

/// This table remembers what somebody types, so the tests that matter most are
/// the ones about what it must *refuse* to remember.
final class NextWordModelTests: XCTestCase {

    // MARK: - Learning and predicting

    func testPredictsAWordItHasSeenFollowAnother() {
        var model = NextWordModel()
        model.learn(previous: ["assalamualaikum"], next: "vhaih")

        XCTAssertEqual(model.predictions(after: ["assalamualaikum"]), ["vhaih"])
    }

    func testKnowsNothingItHasNotSeen() {
        let model = NextWordModel()
        XCTAssertTrue(model.predictions(after: ["hello"]).isEmpty)
        XCTAssertTrue(model.predictions(after: []).isEmpty)
    }

    /// The reason two words of context are stored at all: one word cannot tell
    /// these two phrases apart.
    func testTwoWordsOfContextBeatOne() {
        var model = NextWordModel()
        model.learn(previous: ["how", "are"], next: "you")
        model.learn(previous: ["they", "are"], next: "here")

        XCTAssertEqual(model.predictions(after: ["how", "are"]), ["you"])
        XCTAssertEqual(model.predictions(after: ["they", "are"]), ["here"])
    }

    /// A two-word context it has never seen still answers from the last word.
    func testFallsBackToOneWordWhenThePairIsUnknown() {
        var model = NextWordModel()
        model.learn(previous: ["are"], next: "you")

        XCTAssertEqual(model.predictions(after: ["nobody", "are"]), ["you"])
    }

    func testTheMoreOftenSeenWordWins() {
        var model = NextWordModel()
        model.learn(previous: ["good"], next: "night")
        model.learn(previous: ["good"], next: "morning")
        model.learn(previous: ["good"], next: "morning")

        XCTAssertEqual(model.predictions(after: ["good"], limit: 1), ["morning"])
    }

    func testContextIsCaseInsensitiveButSuggestionsKeepTheirCase() {
        var model = NextWordModel()
        model.learn(previous: ["call"], next: "Tanvir")

        XCTAssertEqual(model.predictions(after: ["CALL"]), ["Tanvir"])
        XCTAssertEqual(model.predictions(after: ["Call"]), ["Tanvir"])
    }

    func testLimitIsRespected() {
        var model = NextWordModel()
        for word in ["one", "two", "three", "four"] {
            model.learn(previous: ["the"], next: word)
        }
        XCTAssertEqual(model.predictions(after: ["the"], limit: 2).count, 2)
    }

    /// Equal counts must not reshuffle between keystrokes — a strip that
    /// reorders itself while you look at it is unusable.
    func testTiesAreBrokenStably() {
        var model = NextWordModel()
        model.learn(previous: ["the"], next: "beta")
        model.learn(previous: ["the"], next: "alpha")

        XCTAssertEqual(model.predictions(after: ["the"]), ["alpha", "beta"])
    }

    // MARK: - Opening a message

    /// An empty field used to be answered with nothing, which left the strip
    /// blank at exactly the moment somebody is deciding what to write.
    func testAnEmptyFieldIsOfferedOpeners() {
        XCTAssertFalse(NextWordSeed.model.predictions(after: []).isEmpty)
    }

    func testTheFirstWordOfAMessageIsLearnedAsAnOpener() {
        var model = NextWordModel()
        model.learn(previous: [], next: "Assalamualaikum")

        XCTAssertEqual(model.predictions(after: []), ["Assalamualaikum"])
    }

    /// The seeded openers are generic; a person's own are not, and should win
    /// as soon as there is evidence of them.
    func testAPersonalOpenerOvertakesTheSeeded() {
        var model = NextWordSeed.model
        for _ in 0 ..< 3 {
            model.learn(previous: [], next: "Assalamualaikum")
        }

        XCTAssertEqual(model.predictions(after: [], limit: 1), ["Assalamualaikum"])
    }

    /// The sentinel must never be reachable as an ordinary context, or a word
    /// typed after it would be offered as an opener.
    func testTheOpenerSentinelIsNotAWord() {
        XCTAssertFalse(NextWordModel.isLearnable(NextWordModel.sentenceStart))
    }

    // MARK: - What it must refuse to remember

    /// The important one. Card numbers, one-time codes, addresses and phone
    /// numbers all arrive as ordinary typing, and a keyboard that offers them
    /// back later is a keyboard that leaks.
    func testAnythingWithADigitIsNeverLearned() {
        XCTAssertFalse(NextWordModel.isLearnable("4111111111111111"))
        XCTAssertFalse(NextWordModel.isLearnable("code123"))
        XCTAssertFalse(NextWordModel.isLearnable("12"))
        XCTAssertFalse(NextWordModel.isLearnable("a1"))

        var model = NextWordModel()
        model.learn(previous: ["my", "card"], next: "4111111111111111")
        model.learn(previous: ["is"], next: "0192")

        XCTAssertTrue(model.predictions(after: ["my", "card"]).isEmpty)
        XCTAssertTrue(model.predictions(after: ["is"]).isEmpty)
    }

    func testBarePunctuationIsNotLearned() {
        XCTAssertFalse(NextWordModel.isLearnable("!"))
        XCTAssertFalse(NextWordModel.isLearnable("--"))
        XCTAssertFalse(NextWordModel.isLearnable("'"))
        XCTAssertFalse(NextWordModel.isLearnable(""))
    }

    /// Single letters are allowed here, unlike in the correction path. "I" and
    /// "a" open most English sentences, and excluding them killed every phrase
    /// that starts with one.
    func testSingleLettersAreLearnable() {
        XCTAssertTrue(NextWordModel.isLearnable("a"))
        XCTAssertTrue(NextWordModel.isLearnable("I"))

        var model = NextWordModel()
        model.learn(previous: ["i"], next: "am")
        XCTAssertEqual(model.predictions(after: ["I"]), ["am"])
    }

    func testAbsurdlyLongRunsAreNotLearned() {
        XCTAssertFalse(NextWordModel.isLearnable(String(repeating: "a", count: 200)))
    }

    func testOrdinaryWordsAreLearnable() {
        XCTAssertTrue(NextWordModel.isLearnable("hello"))
        XCTAssertTrue(NextWordModel.isLearnable("don't"))
        XCTAssertTrue(NextWordModel.isLearnable("well-known"))
        XCTAssertTrue(NextWordModel.isLearnable("Tanvir"))
    }

    /// A digit in the *context* must not poison the entry either.
    func testDigitsInContextAreIgnoredRatherThanStored() {
        var model = NextWordModel()
        model.learn(previous: ["pin", "1234"], next: "please")

        // "1234" is dropped from the context, so it answers from "pin" alone.
        XCTAssertEqual(model.predictions(after: ["pin"]), ["please"])
        XCTAssertTrue(model.predictions(after: ["1234"]).isEmpty)
    }

    // MARK: - Size and lifecycle

    func testPruningKeepsTheMostUsedContexts() {
        var model = NextWordModel()
        model.learn(previous: ["rare"], next: "thing")
        for _ in 0 ..< 5 {
            model.learn(previous: ["common"], next: "thing")
        }

        model.prune(to: 1)

        XCTAssertEqual(model.predictions(after: ["common"]), ["thing"])
        XCTAssertTrue(model.predictions(after: ["rare"]).isEmpty)
    }

    func testPruningDoesNothingWhenAlreadySmallEnough() {
        var model = NextWordModel()
        model.learn(previous: ["one"], next: "two")
        let before = model
        model.prune(to: 100)
        XCTAssertEqual(model, before)
    }

    func testForgettingEverythingLeavesNothingBehind() {
        var model = NextWordModel()
        model.learn(previous: ["good"], next: "morning")
        model.forgetEverything()

        XCTAssertTrue(model.predictions(after: ["good"]).isEmpty)
        XCTAssertEqual(model.contextCount, 0)
    }

    /// It is written to disk between sessions, so a round trip has to be exact.
    func testSurvivesBeingSavedAndLoaded() throws {
        var model = NextWordModel()
        model.learn(previous: ["how", "are"], next: "you")
        model.learn(previous: ["call"], next: "Tanvir")

        let data = try JSONEncoder().encode(model)
        let restored = try JSONDecoder().decode(NextWordModel.self, from: data)

        XCTAssertEqual(restored, model)
        XCTAssertEqual(restored.predictions(after: ["how", "are"]), ["you"])
    }

    // MARK: - The seed

    func testSeedAnswersTheMostOrdinaryOpenings() {
        let model = NextWordSeed.model

        XCTAssertEqual(model.predictions(after: ["thank"], limit: 1), ["you"])
        XCTAssertEqual(model.predictions(after: ["how", "are"], limit: 1), ["you"])
        XCTAssertFalse(model.predictions(after: ["good"]).isEmpty)
    }

    /// One real use has to outweigh a seeded pair immediately, or the generic
    /// list would sit in front of the user's own habits for weeks.
    func testASinglePersonalUseOvertakesTheSeed() {
        var model = NextWordSeed.model
        model.learn(previous: ["thank"], next: "vhaih")
        model.learn(previous: ["thank"], next: "vhaih")

        XCTAssertEqual(model.predictions(after: ["thank"], limit: 1), ["vhaih"])
    }

    func testSeedContainsOnlyLearnableWords() {
        for pair in NextWordSeed.pairs {
            XCTAssertTrue(
                NextWordModel.isLearnable(pair.next),
                "\(pair.next) would be rejected by the model it seeds"
            )
        }
    }
}
