import XCTest
@testable import NibKit

/// Configuration parsing and tool routing. Both are cheap to get wrong in a way
/// that only shows up on a device, which is exactly why they are tested here.
final class NibBackendTests: XCTestCase {

    // MARK: - Reading a configured value

    func testUnsetValuesAreNil() {
        XCTAssertNil(NibBackend.clean(nil))
        XCTAssertNil(NibBackend.clean(""))
        XCTAssertNil(NibBackend.clean("   "))
    }

    /// If the build setting is undefined, Xcode leaves the literal `$(NAME)` in
    /// the plist. Treating that as a real value is the mistake this prevents.
    func testUnexpandedBuildSettingsAreNil() {
        XCTAssertNil(NibBackend.clean("$(NIB_API_BASE_URL)"))
        XCTAssertNil(NibBackend.url(from: "$(NIB_API_BASE_URL)"))
    }

    func testTrimsSurroundingWhitespace() {
        XCTAssertEqual(NibBackend.clean("  https://a.test  "), "https://a.test")
    }

    // MARK: - URL validation

    func testAcceptsHTTPS() {
        XCTAssertEqual(
            NibBackend.url(from: "https://nib.vercel.app")?.absoluteString,
            "https://nib.vercel.app"
        )
    }

    /// The payload is the sentence somebody is in the middle of writing. It does
    /// not go over cleartext to a remote host, whatever the plist says.
    func testRejectsCleartextToARemoteHost() {
        XCTAssertNil(NibBackend.url(from: "http://nib.vercel.app"))
        XCTAssertNil(NibBackend.url(from: "http://192.168.1.4:3000"))
    }

    /// Loopback is the exception, so the service can be run locally.
    func testAllowsCleartextToLoopback() {
        XCTAssertNotNil(NibBackend.url(from: "http://localhost:3000"))
        XCTAssertNotNil(NibBackend.url(from: "http://127.0.0.1:3000"))
    }

    func testRejectsNonsense() {
        XCTAssertNil(NibBackend.url(from: "nib.vercel.app"))
        XCTAssertNil(NibBackend.url(from: "ftp://nib.vercel.app"))
        XCTAssertNil(NibBackend.url(from: "https://"))
    }

    // MARK: - Routing

    func testRoutesOnlyTheNamedToolsToLive() async throws {
        let live = SpyClient(name: "live")
        let stub = SpyClient(name: "stub")
        let client = RoutedAPIClient(live: live, fallback: stub, liveTools: [.fix])

        let fix = try await client.suggest(
            tool: .fix, scope: .sample, options: .none, prompt: nil
        )
        let tone = try await client.suggest(
            tool: .tone, scope: .sample, options: .none, prompt: nil
        )

        XCTAssertEqual(fix, ["live"])
        XCTAssertEqual(tone, ["stub"])
    }

    func testFixIsTheOnlyToolLiveByDefault() {
        XCTAssertEqual(NibBackend.liveTools, [.fix])
    }

    /// A build with no URL set must behave exactly as it did before the backend
    /// existed — this is what makes the wiring safe to ship unconfigured.
    func testAnUnconfiguredBuildUsesTheFallbackForEverything() async throws {
        let stub = SpyClient(name: "stub")
        // `Bundle.main` in a test run is the test bundle, which has no keys —
        // the same state as an app built with the settings left empty.
        let client = NibBackend.makeClient(fallback: stub)

        for tool in NibTool.allCases {
            let result = try await client.suggest(
                tool: tool, scope: .sample, options: .none, prompt: nil
            )
            XCTAssertEqual(result, ["stub"], "\(tool) should be stubbed")
        }
    }
}

private struct SpyClient: NibAPIClient {
    let name: String

    func suggest(
        tool: NibTool,
        scope: TextScope,
        options: ToolOptions,
        prompt: String?
    ) async throws -> [String] {
        [name]
    }
}

private extension TextScope {
    static let sample = TextScope(text: "hello", deleteCount: 5, after: nil)
}
