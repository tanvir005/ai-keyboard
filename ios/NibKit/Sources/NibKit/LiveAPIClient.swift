import Foundation

/// Talks to Nib's own service, which talks to whichever AI provider it was
/// deployed with.
///
/// ## Why the app never talks to Anthropic/OpenAI/Google directly
/// It would need an API key to do that, and a keyboard extension shipped with
/// an API key in it is a key on every phone that installs it — extractable
/// from the IPA in minutes, and billable to us until it is rotated. The key
/// lives in one server environment variable instead. The app knows a URL.
///
/// A useful consequence: switching provider is a redeploy, not an app update.
/// Nothing here names a model, and nothing here would change if it did.
///
/// ## Why the transport is injectable
/// So the request this builds and the responses it survives can be tested with
/// `swift test` on any machine — no simulator, no network, no key. The default
/// is `URLSession`; the tests pass a closure.
public struct LiveAPIClient: NibAPIClient {

    /// A reply reduced to the only two things this client reads.
    ///
    /// `URLResponse` is deliberately not used: it is a class whose `Sendable`
    /// story varies by platform, and none of its other 20 properties matter
    /// here. A struct of `Int` and `Data` crosses actors without argument.
    public struct HTTPReply: Sendable {
        public let status: Int
        public let body: Data

        public init(status: Int, body: Data) {
            self.status = status
            self.body = body
        }
    }

    public typealias Transport = @Sendable (URLRequest) async throws -> HTTPReply

    /// Long enough for a small model to answer, short enough that a dead
    /// network doesn't leave a spinner above someone's keys. The toolbar stays
    /// interactive throughout either way — this only bounds the wait.
    public static let timeout: TimeInterval = 12

    private let endpoint: URL
    private let secret: String?
    private let transport: Transport

    /// - Parameters:
    ///   - baseURL: the deployment root, e.g. `https://nib-abc.vercel.app`.
    ///     The `/api/suggest` path is appended here so callers configure one
    ///     value and cannot get the path wrong.
    ///   - secret: sent as `x-nib-key`. See `NibBackend.appSecret` for why this
    ///     is not, and cannot be, real security.
    public init(baseURL: URL, secret: String? = nil, transport: Transport? = nil) {
        self.endpoint = baseURL.appendingPathComponent("api/suggest")
        self.secret = secret
        self.transport = transport ?? Self.urlSession
    }

    // MARK: - NibAPIClient

    public func suggest(
        tool: NibTool,
        scope: TextScope,
        options: ToolOptions,
        prompt: String?
    ) async throws -> [String] {
        let text = scope.text.trimmingCharacters(in: .whitespacesAndNewlines)

        // The service rejects empty text for every tool, Ask included: an
        // instruction with nothing to apply it to has no answer. Failing here
        // rather than at the server saves a round-trip and gives the user the
        // more useful of the two messages.
        guard !text.isEmpty else { throw NibAPIError.empty }

        let reply = try await send(payload(tool, text, options, prompt))

        // A superseded request must not overwrite a newer one's result. The
        // view model also checks, but a client that quietly returns after
        // cancellation is a client that can only be used carefully.
        if Task.isCancelled { throw CancellationError() }

        try check(reply.status)

        guard let decoded = try? JSONDecoder().decode(Reply.self, from: reply.body) else {
            throw NibAPIError.network
        }

        let suggestions = (decoded.suggestions ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !suggestions.isEmpty else { throw NibAPIError.empty }
        return suggestions
    }

    // MARK: - Request

    private func payload(
        _ tool: NibTool,
        _ text: String,
        _ options: ToolOptions,
        _ prompt: String?
    ) -> Payload {
        // Only the keys the service reads, and only when set. Sending
        // `"targetLanguage": null` on a Fix would be noise in a prompt.
        var wire: [String: String] = [:]
        if let tone = options.tonePreset { wire["tonePreset"] = tone }
        if let language = options.targetLanguage { wire["targetLanguage"] = language }

        return Payload(
            tool: tool.rawValue,
            text: text,
            options: wire.isEmpty ? nil : wire,
            prompt: prompt?.isEmpty == false ? prompt : nil
        )
    }

    private func send(_ payload: Payload) async throws -> HTTPReply {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if let secret { request.setValue(secret, forHTTPHeaderField: "x-nib-key") }
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            return try await transport(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // URLSession's errors are about DNS, TLS and airplane mode. None of
            // them are worth showing to somebody mid-sentence.
            throw NibAPIError.network
        }
    }

    private func check(_ status: Int) throws {
        switch status {
        case 200..<300:
            return
        case 401, 403:
            // The key is missing or wrong — ours to fix, not the user's, so it
            // reads as "not set up" rather than as a network problem they
            // might waste time troubleshooting.
            throw NibAPIError.notConfigured
        case 429:
            throw NibAPIError.quotaExceeded
        default:
            throw NibAPIError.network
        }
    }

    // MARK: - Wire types

    private struct Payload: Encodable {
        let tool: String
        let text: String
        let options: [String: String]?
        let prompt: String?
    }

    private struct Reply: Decodable {
        let suggestions: [String]?
        /// Echoed by the service so a suggestion can be traced to what produced
        /// it. Unused by the UI today; decoded so that adding it later is a
        /// display change and not a protocol change.
        let model: String?
    }

    // MARK: - Default transport

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        // Ephemeral keeps caches, cookies and credentials in memory only.
        // What people type is the most sensitive thing this app handles; none
        // of it should outlive the process in a cache file.
        configuration.timeoutIntervalForRequest = LiveAPIClient.timeout
        configuration.timeoutIntervalForResource = LiveAPIClient.timeout
        // Fail fast instead of parking the request until the network returns.
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    private static let urlSession: Transport = { request in
        let (data, response) = try await LiveAPIClient.session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPReply(status: status, body: data)
    }
}
