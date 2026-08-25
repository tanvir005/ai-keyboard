import XCTest
@testable import NibKit

/// A hand-typed catalogue is exactly where a stray space or a duplicated glyph
/// hides — neither shows up as a build error, and both look fine until someone
/// scrolls to the wrong row.
final class EmojiCatalogTests: XCTestCase {

    func testEveryCategoryHasContent() {
        XCTAssertFalse(EmojiCatalog.categories.isEmpty)
        for category in EmojiCatalog.categories {
            XCTAssertFalse(category.emoji.isEmpty, "\(category.id) is empty")
            XCTAssertFalse(category.id.isEmpty)
        }
    }

    func testCategoryIdsAreUnique() {
        let ids = EmojiCatalog.categories.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "two categories share an id")
    }

    /// A tab whose glyph is not in its own category is a labelling mistake.
    func testEachCategorySymbolComesFromItsOwnContents() {
        for category in EmojiCatalog.categories {
            XCTAssertTrue(
                category.emoji.contains(category.symbol),
                "\(category.id) is tabbed with \(category.symbol), which it does not contain"
            )
        }
    }

    /// Each cell renders one glyph. A stray space or a pair typed into one
    /// string would silently break the grid's alignment.
    func testEveryEntryIsASingleGrapheme() {
        for category in EmojiCatalog.categories {
            for glyph in category.emoji {
                XCTAssertEqual(
                    glyph.count, 1,
                    "\(glyph) in \(category.id) is \(glyph.count) characters, not 1"
                )
                XCTAssertFalse(
                    glyph.contains(" "),
                    "\(glyph) in \(category.id) contains a space"
                )
            }
        }
    }

    func testNoDuplicatesWithinACategory() {
        for category in EmojiCatalog.categories {
            let seen = Set(category.emoji)
            XCTAssertEqual(
                seen.count, category.emoji.count,
                "\(category.id) repeats a glyph"
            )
        }
    }

    func testCatalogueIsBigEnoughToBeWorthAPage() {
        XCTAssertGreaterThan(EmojiCatalog.all.count, 400)
    }
}
