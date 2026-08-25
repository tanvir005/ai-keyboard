import XCTest
@testable import NibKit

/// The alternates row is a drag-tracking gesture, which is the kind of thing
/// that compiles happily and misbehaves in the hand. These cover the parts that
/// do not need a finger: the table itself, and the arithmetic that decides which
/// glyph the finger is over.
final class KeyAlternatesTests: XCTestCase {

    // MARK: - The row

    func testHeldKeyOffersItselfFirst() {
        XCTAssertEqual(KeyAlternates.row(for: "o").first, "o")
        XCTAssertEqual(KeyAlternates.row(for: "$").first, "$")
    }

    /// Holding a key with nothing to offer must open nothing at all, rather
    /// than a panel containing only the character already being typed.
    func testKeyWithoutAlternatesOpensNothing() {
        for character in ["q", "w", "r", "t", "p", "f", "h", "j", "k", "x", "v", "b", "m"] {
            XCTAssertTrue(
                KeyAlternates.row(for: character).isEmpty,
                "\(character) should not open an alternates row"
            )
        }
    }

    func testUppercaseKeyOffersUppercaseAlternates() {
        let row = KeyAlternates.row(for: "O")
        XCTAssertEqual(row.first, "O")
        XCTAssertFalse(row.isEmpty)
        for glyph in row {
            XCTAssertEqual(glyph, glyph.uppercased(), "\(glyph) should be uppercase")
        }
    }

    /// ß uppercases to "SS". Two characters on a key cap is not what anyone is
    /// holding S to find, so it is dropped rather than shown.
    func testAlternatesWithoutASingleCharacterCapitalAreDropped() {
        let row = KeyAlternates.row(for: "S")
        XCTAssertEqual(row.first, "S")
        XCTAssertFalse(row.contains("SS"))
        XCTAssertFalse(row.contains("ß"))
    }

    func testLowercaseRowKeepsCharactersWithNoCapital() {
        XCTAssertTrue(KeyAlternates.row(for: "s").contains("ß"))
    }

    func testEveryGlyphIsExactlyOneCharacter() {
        for key in KeyAlternates.keysWithAlternates {
            for glyph in KeyAlternates.row(for: key) {
                XCTAssertEqual(glyph.count, 1, "\(glyph) on key \(key) is not a single character")
            }
        }
    }

    func testRowsHaveNoDuplicates() {
        for key in KeyAlternates.keysWithAlternates {
            let row = KeyAlternates.row(for: key)
            XCTAssertEqual(Set(row).count, row.count, "key \(key) repeats a glyph")
        }
    }

    /// A row wider than the keyboard would be clipped, and the clipped items
    /// would be unreachable — the finger cannot drag to something off screen.
    func testRowsFitOnScreen() {
        for key in KeyAlternates.keysWithAlternates {
            XCTAssertLessThanOrEqual(
                KeyAlternates.row(for: key).count,
                KeyAlternates.maximumRowLength,
                "key \(key) opens a row too wide to show"
            )
        }
    }

    // MARK: - Which item the finger is over

    func testIndexPicksTheItemUnderTheFinger() {
        // Five items, 40pt each, starting at x = 100.
        let left: CGFloat = 100
        let width: CGFloat = 40

        XCTAssertEqual(index(at: 100, left, width, 5), 0)
        XCTAssertEqual(index(at: 139, left, width, 5), 0)
        XCTAssertEqual(index(at: 140, left, width, 5), 1)
        XCTAssertEqual(index(at: 219, left, width, 5), 2)
        XCTAssertEqual(index(at: 299, left, width, 5), 4)
    }

    /// Dragging past either end holds the outermost item. Selecting nothing
    /// would mean a slightly-too-far drag inserts the wrong glyph.
    func testIndexClampsBeyondBothEnds() {
        XCTAssertEqual(index(at: -500, 100, 40, 5), 0)
        XCTAssertEqual(index(at: 99, 100, 40, 5), 0)
        XCTAssertEqual(index(at: 300, 100, 40, 5), 4)
        XCTAssertEqual(index(at: 5_000, 100, 40, 5), 4)
    }

    func testIndexIsSafeOnDegenerateRows() {
        XCTAssertEqual(index(at: 250, 100, 40, 0), 0)
        XCTAssertEqual(index(at: 250, 100, 0, 5), 0)
    }

    /// Every point across a row's own width must map back into that row —
    /// the property that guarantees there is no dead gap between items.
    func testEveryPointInsideARowSelectsSomething() {
        for key in KeyAlternates.keysWithAlternates {
            let count = KeyAlternates.row(for: key).count
            let width: CGFloat = 38
            for step in 0 ..< (count * 10) {
                let x = CGFloat(step) * width / 10
                let picked = index(at: x, 0, width, count)
                XCTAssertTrue(
                    (0 ..< count).contains(picked),
                    "x=\(x) on key \(key) selected \(picked), outside 0..<\(count)"
                )
            }
        }
    }

    // MARK: - Which way the row opens

    func testKeysPastHalfwayOpenLeftward() {
        XCTAssertFalse(KeyAlternates.opensLeftward(keyCenterX: 40, boardWidth: 400))
        XCTAssertFalse(KeyAlternates.opensLeftward(keyCenterX: 199, boardWidth: 400))
        XCTAssertTrue(KeyAlternates.opensLeftward(keyCenterX: 201, boardWidth: 400))
        XCTAssertTrue(KeyAlternates.opensLeftward(keyCenterX: 380, boardWidth: 400))
    }

    /// The whole point of the anchoring: whichever way the row opens, the glyph
    /// the finger is already on must be the one under it.
    func testBaseGlyphLandsOverTheKeyThatOpenedTheRow() {
        let keyWidth: CGFloat = 33
        let itemWidth: CGFloat = 38
        let padding: CGFloat = 4

        for (centerX, leftward) in [(60.0, false), (330.0, true)] as [(CGFloat, Bool)] {
            let count = 5
            let rowWidth = itemWidth * CGFloat(count) + padding * 2
            let left = KeyAlternates.rowLeft(
                keyCenterX: centerX,
                keyWidth: keyWidth,
                rowWidth: rowWidth,
                boardWidth: 393,
                boardInset: 6,
                padding: padding,
                opensLeftward: leftward
            )

            // Reversed for a leftward row, so the base sits at the far end.
            let baseIndex = leftward ? count - 1 : 0
            let baseCentre = left + padding + itemWidth * (CGFloat(baseIndex) + 0.5)

            XCTAssertEqual(
                baseCentre, centerX, accuracy: itemWidth / 2,
                "base glyph drifted off its key (leftward: \(leftward))"
            )
        }
    }

    func testRowIsPushedBackInsideTheBoard() {
        let boardWidth: CGFloat = 393
        let inset: CGFloat = 6
        let rowWidth: CGFloat = 350

        for centerX in stride(from: CGFloat(10), through: 383, by: 10) {
            for leftward in [true, false] {
                let left = KeyAlternates.rowLeft(
                    keyCenterX: centerX,
                    keyWidth: 33,
                    rowWidth: rowWidth,
                    boardWidth: boardWidth,
                    boardInset: inset,
                    padding: 4,
                    opensLeftward: leftward
                )
                XCTAssertGreaterThanOrEqual(left, inset, "row ran off the left edge")
                XCTAssertLessThanOrEqual(
                    left + rowWidth, boardWidth - inset,
                    "row ran off the right edge"
                )
            }
        }
    }

    /// Degenerate but reachable on a very narrow device: pin left rather than
    /// invert the clamp and land somewhere nonsensical.
    func testRowWiderThanTheBoardPinsToTheLeftInset() {
        let left = KeyAlternates.rowLeft(
            keyCenterX: 200,
            keyWidth: 33,
            rowWidth: 900,
            boardWidth: 393,
            boardInset: 6,
            padding: 4,
            opensLeftward: true
        )
        XCTAssertEqual(left, 6)
    }

    private func index(
        at x: CGFloat,
        _ left: CGFloat,
        _ width: CGFloat,
        _ count: Int
    ) -> Int {
        KeyAlternates.index(forX: x, rowLeft: left, itemWidth: width, count: count)
    }
}
