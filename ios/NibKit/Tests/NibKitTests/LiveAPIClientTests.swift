import XCTest
@testable import NibKit

/// The transport is injected, so every one of these runs offline, in
/// milliseconds, with no key and no deployment.
final class LiveAPIClientTests: XCTestCase {

    private let base = URL(string: "https://example.test")!
    private let scope = TextScope(text: "teh cat", deleteCount: 7, after: nil)

    // MARK: - Helpers

    /// Captures the request and returns a canned reply.
    private func client(
        status: Int = 200,
        body: String = #"{"suggestions":["the cat"],"model":"m"}"#,
        secret: String? = nil,
        capture: Captured? = nil
    ) -> LiveAPIClient {
        LiveAPIClient(baseURL: base, secret: secret) { request in
            capture?.set(request)
            return .init(status: status, body: Data(body.utf8))
        }
    }

    private func suggest(
        _ client: LiveAPIClient,
        tool: NibTool = .fix,
        scope: TextScope? = nil,
        options: ToolOptions = .none,
        prompt: String? = nil
    ) async throws -> [String] {
        try await client.suggest(
            tool: tool, scope: scope ?? self.scope, options: options, prompt: prompt
        )
    }

    /// Runs a request expected to fail and returns the error it produced.
    private func failure(status: Int = 200, body: String) async -> NibAPIError? {
        do {
            _ = try await suggest(client(status: status, body: body))
            return nil
        } catch {
            return error as? NibAPIError
        }
    }

    // MARK: - The request

    func testPostsToTheSuggestPath() async throws {
        let seen = Captured()
        _ = try await suggest(client(capture: seen))

        XCTAssertEqual(seen.request?.url?.absoluteString, "https://example.test/api/suggest")
        XCTAssertEqual(seen.request?.httpMethod, "POST")
        XCTAssertEqual(
            seen.request?.value(forHTTPHeaderField: "content-type"),
            "application/json"
        )
    }

    func testSendsToolAndTextInTheBody() async throws {
        let seen = Captured()
        _ = try await suggest(client(capture: seen))

        let body = try XCTUnwrap(seen.body)
        XCTAssertEqual(body["tool"] as? String, "fix")
        XCTAssertEqual(body["text"] as? String, "teh cat")
    }

    /// Sending a null language on a Fix would be noise in the prompt.
    func testOmitsOptionsThatWereNotSet() async throws {
        let seen = Captured()
        _ = try await suggest(client(capture: seen))

        let body = try XCTUnwrap(seen.body)
        XCTAssertNil(body["options"])
        XCTAssertNil(body["prompt"])
    }

    func testSendsOnlyTheOptionsThatWereSet() async throws {
        let seen = Captured()
        _ = try await suggest(
            client(capture: seen),
            tool: .tone,
            options: ToolOptions(tonePreset: "Warmer")
        )

        let options = try XCTUnwrap(try XCTUnwrap(seen.body)["options"] as? [String: String])
        XCTAssertEqual(options, ["tonePreset": "Warmer"])
    }

    func testSendsTheSecretWhenThereIsOne() async throws {
        let seen = Captured()
        _ = try await suggest(client(secret: "s3cret", capture: seen))

        XCTAssertEqual(seen.request?.value(forHTTPHeaderField: "x-nib-key"), "s3cret")
    }

    func testSendsNoKeyHeaderWhenThereIsNoSecret() async throws {
        let seen = Captured()
        _ = try await suggest(client(capture: seen))

        XCTAssertNil(seen.request?.value(forHTTPHeaderField: "x-nib-key"))
    }

    /// Leading whitespace is not content the model should be asked to preserve.
    func testTrimsTheTextItSends() async throws {
        let seen = Captured()
        _ = try await suggest(
            client(capture: seen),
            scope: TextScope(text: "  hello  ", deleteCount: 9, after: nil)
        )

        XCTAssertEqual(try XCTUnwrap(seen.body)["text"] as? String, "hello")
    }

    // MARK: - The response

    func testReturnsSuggestions() async throws {
        let result = try await suggest(
            client(body: #"{"suggestions":["the cat","The cat."],"model":"m"}"#)
        )
        XCTAssertEqual(result, ["the cat", "The cat."])
    }

    func testDropsBlankSuggestions() async throws {
        let result = try await suggest(
            client(body: #"{"suggestions":["the cat","   ",""],"model":"m"}"#)
        )
        XCTAssertEqual(result, ["the cat"])
    }

    /// An unknown key must not break decoding: the service is deployed
    /// separately from the app, so it will sometimes be newer.
    func testIgnoresFieldsItDoesNotKnow() async throws {
        let result = try await suggest(
            client(body: #"{"suggestions":["ok"],"model":"m","latencyMs":42}"#)
        )
        XCTAssertEqual(result, ["ok"])
    }

    // MARK: - Failure

    func testEmptyTextNeverReachesTheNetwork() async {
        let reached = Captured()
        let blank = TextScope(text: "   ", deleteCount: 3, after: nil)

        do {
            _ = try await suggest(client(capture: reached), scope: blank)
            XCTFail("expected .empty")
        } catch {
            XCTAssertEqual(error as? NibAPIError, .empty)
        }
        XCTAssertNil(reached.request)
    }

    func testNoSuggestionsIsEmptyNotSuccess() async {
        let result = await failure(body: #"{"suggestions":[],"model":"m"}"#)
        XCTAssertEqual(result, .empty)
    }

    func testUnparseableBodyIsANetworkError() async {
        let result = await failure(body: "<html>502 Bad Gateway</html>")
        XCTAssertEqual(result, .network)
    }

    func testRejectedKeyReadsAsNotConfigured() async {
        let unauthorised = await failure(status: 401, body: #"{"error":"Not authorised."}"#)
        let forbidden = await failure(status: 403, body: #"{"error":"Not authorised."}"#)

        XCTAssertEqual(unauthorised, .notConfigured)
        XCTAssertEqual(forbidden, .notConfigured)
    }

    func testTooManyRequestsReadsAsQuota() async {
        let result = await failure(status: 429, body: #"{"error":"slow down"}"#)
        XCTAssertEqual(result, .quotaExceeded)
    }

    func testUpstreamFailureIsANetworkError() async {
        let result = await failure(status: 502, body: #"{"error":"Upstream failed."}"#)
        XCTAssertEqual(result, .network)
    }

    func testBadRequestIsANetworkError() async {
        let result = await failure(status: 400, body: #"{"error":"text too long"}"#)
        XCTAssertEqual(result, .network)
    }

    /// URLSession's errors are about DNS, TLS and airplane mode. None of them
    /// should escape as themselves.
    func testTransportErrorsBecomeNetworkErrors() async {
        struct Boom: Error {}
        let client = LiveAPIClient(baseURL: base) { _ in throw Boom() }

        do {
            _ = try await suggest(client)
            XCTFail("expected .network")
        } catch {
            XCTAssertEqual(error as? NibAPIError, .network)
        }
    }

    func testCancellationStaysCancellation() async {
        let client = LiveAPIClient(baseURL: base) { _ in throw CancellationError() }

        do {
            _ = try await suggest(client)
            XCTFail("expected CancellationError")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
}

/// Somewhere for a `@Sendable` closure to leave what it saw.
private final class Captured: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: URLRequest?

    func set(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        stored = request
    }

    var request: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    var body: [String: Any]? {
        guard let data = request?.httpBody else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
