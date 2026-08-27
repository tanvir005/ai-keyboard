import XCTest
@testable import NibKit

/// Small sizes only. The point here is that the probe measures what it claims
/// to measure — the real experiment is 30 MB inside a keyboard extension on a
/// phone, which no test runner can stand in for.
final class MemoryProbeTests: XCTestCase {

    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("nib-probe-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    func testFootprintIsAPlausibleNumber() throws {
        let bytes = try XCTUnwrap(MemoryProbe.footprintBytes, "task_info should answer on Darwin")

        // A running process holds more than a megabyte and less than 64 GB. The
        // test is not the value but the units: reading the wrong field of
        // `task_vm_info` returns something that looks fine until it is compared
        // against anything.
        XCTAssertGreaterThan(bytes, 1024 * 1024)
        XCTAssertLessThan(bytes, 64 * 1024 * 1024 * 1024)
    }

    func testMapsAFileOfTheRequestedSize() throws {
        let file = try MemoryProbe.mapFile(megabytes: 2, directory: scratch)
        XCTAssertEqual(file.megabytes, 2)
    }

    /// The probe writes a known byte, so this proves the mapping really
    /// reaches the file rather than some empty region.
    func testMappedPagesHoldTheWrittenBytes() throws {
        let file = try MemoryProbe.mapFile(megabytes: 1, directory: scratch)
        XCTAssertEqual(file.firstByte, 0x4E)
    }

    /// Every page has to be read, not just the first — an untouched mapping
    /// costs nothing and would report a success that means nothing.
    func testTouchesEveryPage() throws {
        let file = try MemoryProbe.mapFile(megabytes: 1, directory: scratch)
        let expected = (1024 * 1024) / Int(getpagesize())
        XCTAssertEqual(file.touchAllPages(), expected)
    }

    /// Released by clearing the reference rather than by leaving a scope:
    /// Swift does not promise to destroy a local at the closing brace, so a
    /// `do { }` block here would test the optimiser's mood, not the code.
    func testUnmappingRemovesTheFile() throws {
        let path = scratch.appendingPathComponent("nib-memory-probe-1mb.bin")

        var file: MemoryProbe.MappedFile? = try MemoryProbe.mapFile(
            megabytes: 1, directory: scratch
        )
        file?.touchAllPages()
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))

        file = nil
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: path.path),
            "releasing the mapping should clean up after itself"
        )
    }

    func testHeapAllocationIsTheRequestedSize() {
        let data = MemoryProbe.allocateHeap(megabytes: 2)
        XCTAssertEqual(data.count, 2 * 1024 * 1024)
        XCTAssertEqual(data.first, 0x4E, "first page should have been written to")
    }

    /// The comparison the whole probe exists to make: dirty heap pages are
    /// charged, and this is the side of it a test can actually observe.
    ///
    /// The threshold is well under the amount allocated on purpose. This is
    /// checking that written heap is charged at all, not measuring how much —
    /// a shared runner's footprint moves under its own steam, and a tight
    /// bound here would fail for reasons that have nothing to do with the code.
    func testHeapAllocationRaisesTheFootprint() throws {
        let before = try XCTUnwrap(MemoryProbe.footprintBytes)
        let data = MemoryProbe.allocateHeap(megabytes: 32)
        let after = try XCTUnwrap(MemoryProbe.footprintBytes)

        XCTAssertGreaterThan(
            after, before + 8 * 1024 * 1024,
            "32 MB of written heap should show up in the footprint"
        )
        withExtendedLifetime(data) {}
    }
}
