import XCTest
@testable import NibKit

final class TypingRulesTests: XCTestCase {

    // MARK: - Double space

    func testSecondSpaceAfterAWordBecomesAFullStop() {
        XCTAssertTrue(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "hello "))
        XCTAssertTrue(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "one two three "))
        XCTAssertTrue(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "ok "))
        XCTAssertTrue(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "1 "))
    }

    /// Someone lining text up with spaces is not asking for punctuation.
    func testDeliberateDoubleSpacingIsLeftAlone() {
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "hello  "))
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "hello   "))
    }

    /// The caret is not after a word, so there is nothing to end.
    func testLeadingSpaceIsLeftAlone() {
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: " "))
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: ""))
    }

    func testASentenceIsNeverGivenTwoTerminators() {
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "done. "))
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "really? "))
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "stop! "))
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "wait, "))
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "note: "))
    }

    func testTextNotEndingInASpaceIsNeverPromoted() {
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "hello"))
        XCTAssertFalse(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "hello\n"))
    }

    /// Emoji end words too, and are more than one scalar — a naive last-scalar
    /// check would get this wrong.
    func testAWordEndingInAnEmojiStillPromotes() {
        XCTAssertTrue(TypingRules.shouldPromoteSpaceToSentenceBreak(before: "nice 👨‍👩‍👧‍👦 "))
    }

    // MARK: - Releasing a key

    private let key = CGSize(width: 33, height: 42)

    func testReleaseOnTheKeyCommitsIt() {
        XCTAssertTrue(commits(CGPoint(x: 16, y: 21)))
        XCTAssertTrue(commits(CGPoint(x: 0, y: 0)))
        XCTAssertTrue(commits(CGPoint(x: 33, y: 42)))
    }

    /// The gaps between keys are 6pt, so an 8pt slop means a thumb resting just
    /// off the edge still types rather than silently losing the keystroke.
    func testReleaseJustOffTheEdgeStillCommits() {
        XCTAssertTrue(commits(CGPoint(x: -6, y: 21)))
        XCTAssertTrue(commits(CGPoint(x: 39, y: 21)))
        XCTAssertTrue(commits(CGPoint(x: 16, y: -7)))
    }

    /// The bug this rule exists for: pressing one key, dragging across the
    /// board and releasing used to type the key you started on.
    func testReleaseFarFromTheKeyCancelsIt() {
        XCTAssertFalse(commits(CGPoint(x: 300, y: 21)))
        XCTAssertFalse(commits(CGPoint(x: -120, y: 21)))
        XCTAssertFalse(commits(CGPoint(x: 16, y: 200)))
        XCTAssertFalse(commits(CGPoint(x: 16, y: -60)))
    }

    private func commits(_ location: CGPoint) -> Bool {
        TypingRules.releaseCommitsKey(location: location, size: key)
    }
}
