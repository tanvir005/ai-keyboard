import XCTest
@testable import NibKit

/// The transport is injected, so every one of these runs offline, in
/// milliseconds, with no key and no network.
final class OpenAIClientTests: XCTestCase {

    private let scope = TextScope(text: "i cant make it", deleteCount: 14, after: nil)

    // MARK: - Helpers

    private func client(
        status: Int = 200,
        body: String = #"{"choices":[{"message":{"role":"assistant","content":"done"}}]}"#,
        model: String = "gpt-4o-mini",
        capture: Captured? = nil
    ) -> OpenAIClient {
        OpenAIClient(apiKey: "sk-test", model: model) { request in
            capture?.set(request)
            return .init(status: status, body: Data(body.utf8))
        }
    }

    private func suggest(
        _ client: OpenAIClient,
        tool: NibTool = .rewrite,
        scope: TextScope? = nil,
        options: ToolOptions = .none,
        prompt: String? = nil
    ) async throws -> [String] {
        try await client.suggest(
            tool: tool, scope: scope ?? self.scope, options: options, prompt: prompt
        )
    }

    private func failure(status: Int = 200, body: String) async -> NibAPIError? {
        do {
            _ = try await suggest(client(status: status, body: body))
            return nil
        } catch {
            return error as? NibAPIError
        }
    }

    /// A minimal Chat Completions reply with one choice per content string.
    private static func reply(_ contents: String...) -> String {
        let choices = contents
            .map { #"{"message":{"role":"assistant","content":"\#($0)"}}"# }
            .joined(separator: ",")
        return #"{"choices":[\#(choices)]}"#
    }

    // MARK: - The request

    func testPostsToChatCompletions() async throws {
        let seen = Captured()
        _ = try await suggest(client(capture: seen))

        XCTAssertEqual(
            seen.request?.url?.absoluteString,
            "https://api.openai.com/v1/chat/completions"
        )
        XCTAssertEqual(seen.request?.httpMethod, "POST")
        XCTAssertEqual(
            seen.request?.value(forHTTPHeaderField: "content-type"),
            "application/json"
        )
    }

    func testSendsTheKeyAsABearerToken() async throws {
        let seen = Captured()
        _ = try await suggest(client(capture: seen))

        XCTAssertEqual(
            seen.request?.value(forHTTPHeaderField: "authorization"),
            "Bearer sk-test"
        )
    }

    func testSendsTheConfiguredModel() async throws {
        let seen = Captured()
        _ = try await suggest(client(model: "gpt-4o", capture: seen))

        XCTAssertEqual(try XCTUnwrap(seen.body)["model"] as? String, "gpt-4o")
    }

    func testPutsTheUsersTextInAUserMessage() async throws {
        let seen = Captured()
        _ = try await suggest(client(capture: seen))

        let messages = try XCTUnwrap(try XCTUnwrap(seen.body)["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages.first?["role"] as? String, "system")
        XCTAssertEqual(messages.last?["role"] as? String, "user")
        XCTAssertEqual(messages.last?["content"] as? String, "i cant make it")
    }

    /// Rewrite and Tone earn a strip of alternatives; a translation has one
    /// right answer, so asking for more is just latency.
    func testAsksForMultipleVariantsOnlyWhereTheyHelp() async throws {
        let rewrite = Captured()
        _ = try await suggest(client(capture: rewrite), tool: .rewrite)
        XCTAssertEqual(try XCTUnwrap(rewrite.body)["n"] as? Int, 3)

        let translate = Captured()
        _ = try await suggest(
            client(capture: translate),
            tool: .translate,
            options: ToolOptions(targetLanguage: "French")
        )
        XCTAssertEqual(try XCTUnwrap(translate.body)["n"] as? Int, 1)
    }

    func testToneNameLandsInTheSystemPrompt() async throws {
        let seen = Captured()
        _ = try await suggest(
            client(capture: seen),
            tool: .tone,
            options: ToolOptions(tonePreset: "professional")
        )

        let messages = try XCTUnwrap(try XCTUnwrap(seen.body)["messages"] as? [[String: Any]])
        let system = try XCTUnwrap(messages.first?["content"] as? String)
        XCTAssertTrue(system.contains("professional"), "system prompt was: \(system)")
    }

    /// A custom preset arrives as a full instruction in `prompt`; it should win
    /// over the preset name.
    func testCustomToneInstructionIsUsed() async throws {
        let seen = Captured()
        _ = try await suggest(
            client(capture: seen),
            tool: .tone,
            options: ToolOptions(tonePreset: "Warmer"),
            prompt: "like a pirate"
        )

        let messages = try XCTUnwrap(try XCTUnwrap(seen.body)["messages"] as? [[String: Any]])
        let system = try XCTUnwrap(messages.first?["content"] as? String)
        XCTAssertTrue(system.contains("like a pirate"), "system prompt was: \(system)")
    }

    func testTargetLanguageLandsInTheSystemPrompt() async throws {
        let seen = Captured()
        _ = try await suggest(
            client(capture: seen),
            tool: .translate,
            options: ToolOptions(targetLanguage: "Japanese")
        )

        let messages = try XCTUnwrap(try XCTUnwrap(seen.body)["messages"] as? [[String: Any]])
        let system = try XCTUnwrap(messages.first?["content"] as? String)
        XCTAssertTrue(system.contains("Japanese"), "system prompt was: \(system)")
    }

    // MARK: - Synonyms

    /// One completion listing several words becomes several suggestions.
    func testSynonymsSplitsAListIntoSeparateSuggestions() async throws {
        let result = try await suggest(
            client(body: Self.reply("quick\\nfast\\nrapid")),
            tool: .synonyms,
            scope: TextScope(text: "speedy", deleteCount: 6, after: nil)
        )
        XCTAssertEqual(result, ["quick", "fast", "rapid"])
    }

    /// Models number or bullet the list even when told not to; those markers
    /// must be stripped so what lands in the strip is paste-ready.
    func testSynonymsStripsLeadingListMarkers() async throws {
        let result = try await suggest(
            client(body: Self.reply("1. quick\\n2) fast\\n- rapid\\n• swift")),
            tool: .synonyms,
            scope: TextScope(text: "speedy", deleteCount: 6, after: nil)
        )
        XCTAssertEqual(result, ["quick", "fast", "rapid", "swift"])
    }

    // MARK: - Ask

    /// Ask is driven by the typed question; the surrounding text is only context,
    /// so an empty draft must still reach the network.
    func testAskWithEmptyDraftStillAsks() async throws {
        let seen = Captured()
        let result = try await suggest(
            client(body: Self.reply("Sure — try this."), capture: seen),
            tool: .ask,
            scope: .empty,
            prompt: "how do I say no politely?"
        )

        XCTAssertEqual(result, ["Sure — try this."])
        let messages = try XCTUnwrap(try XCTUnwrap(seen.body)["messages"] as? [[String: Any]])
        // system + the question, no context message when the draft is empty.
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages.last?["content"] as? String, "how do I say no politely?")
    }

    /// A blank question has nothing to answer and must not reach the network.
    func testAskWithNoQuestionIsEmpty() async {
        let reached = Captured()
        do {
            _ = try await suggest(
                client(capture: reached), tool: .ask, scope: .empty, prompt: "   "
            )
            XCTFail("expected .empty")
        } catch {
            XCTAssertEqual(error as? NibAPIError, .empty)
        }
        XCTAssertNil(reached.request)
    }

    /// When there is a draft, it rides along as a separate context message ahead
    /// of the question.
    func testAskSendsTheDraftAsContext() async throws {
        let seen = Captured()
        _ = try await suggest(
            client(capture: seen),
            tool: .ask,
            scope: TextScope(text: "Dear team,", deleteCount: 10, after: nil),
            prompt: "make this sound friendlier"
        )

        let messages = try XCTUnwrap(try XCTUnwrap(seen.body)["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 3)
        XCTAssertTrue(
            (messages[1]["content"] as? String)?.contains("Dear team,") ?? false,
            "context message was: \(messages[1]["content"] ?? "nil")"
        )
        XCTAssertEqual(messages.last?["content"] as? String, "make this sound friendlier")
    }

    // MARK: - The response

    func testReturnsEveryChoice() async throws {
        let result = try await suggest(
            client(body: Self.reply("I can't make it", "Sorry, I can't make it"))
        )
        XCTAssertEqual(result, ["I can't make it", "Sorry, I can't make it"])
    }

    func testStripsSurroundingQuotesAndWhitespace() async throws {
        let result = try await suggest(client(body: Self.reply("  \\\"hello\\\"  ")))
        XCTAssertEqual(result, ["hello"])
    }

    func testDropsDuplicateChoices() async throws {
        let result = try await suggest(client(body: Self.reply("same", "same")))
        XCTAssertEqual(result, ["same"])
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

    func testNoChoicesIsEmptyNotSuccess() async {
        let result = await failure(body: #"{"choices":[]}"#)
        XCTAssertEqual(result, .empty)
    }

    func testUnparseableBodyIsANetworkError() async {
        let result = await failure(body: "<html>502 Bad Gateway</html>")
        XCTAssertEqual(result, .network)
    }

    func testRejectedKeyReadsAsNotConfigured() async {
        let unauthorised = await failure(status: 401, body: #"{"error":{"message":"bad key"}}"#)
        let forbidden = await failure(status: 403, body: #"{"error":{"message":"no access"}}"#)

        XCTAssertEqual(unauthorised, .notConfigured)
        XCTAssertEqual(forbidden, .notConfigured)
    }

    func testTooManyRequestsReadsAsQuota() async {
        let result = await failure(status: 429, body: #"{"error":{"message":"rate limit"}}"#)
        XCTAssertEqual(result, .quotaExceeded)
    }

    func testUpstreamFailureIsANetworkError() async {
        let result = await failure(status: 500, body: #"{"error":{"message":"oops"}}"#)
        XCTAssertEqual(result, .network)
    }

    func testTransportErrorsBecomeNetworkErrors() async {
        struct Boom: Error {}
        let client = OpenAIClient(apiKey: "sk-test") { _ in throw Boom() }

        do {
            _ = try await suggest(client)
            XCTFail("expected .network")
        } catch {
            XCTAssertEqual(error as? NibAPIError, .network)
        }
    }

    func testCancellationStaysCancellation() async {
        let client = OpenAIClient(apiKey: "sk-test") { _ in throw CancellationError() }

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
