import Foundation

/// Talks to OpenAI's Chat Completions API directly from the device.
///
/// ## The trade-off this makes
/// `LiveAPIClient` explains at length why the app normally does *not* hold a
/// provider key: a keyboard extension shipped with one is a key on every phone
/// that installs it, extractable from the IPA and billable until rotated. This
/// client accepts that trade deliberately — it is wired in only when a build
/// carries `NIB_OPENAI_KEY`, and only for the taste-based tools (Rewrite, Tone,
/// Translate) whose answers a hosted service was never going to gate anyway.
/// Fix keeps going through Nib's own service; see `NibBackend.makeClient()`.
///
/// ## Why the transport is injectable
/// Same reason as `LiveAPIClient`: the request this builds and the replies it
/// survives are tested with `swift test` — no simulator, no network, no key.
public struct OpenAIClient: NibAPIClient {

    public typealias Transport = @Sendable (URLRequest) async throws -> LiveAPIClient.HTTPReply

    /// Long enough for a small model to answer a one-sentence edit, short enough
    /// that a dead network doesn't leave a spinner above someone's keys.
    public static let timeout: TimeInterval = 15

    public static let defaultModel = "gpt-4o-mini"

    /// Chat Completions is the broadest-compatibility endpoint across models.
    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private let apiKey: String
    private let model: String
    private let transport: Transport

    public init(apiKey: String, model: String = defaultModel, transport: Transport? = nil) {
        self.apiKey = apiKey
        self.model = model
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
        let ask = prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Ask is driven by the typed question, not the surrounding text — which
        // is often empty, because the user is asking *before* writing anything.
        // Every other tool edits text that has to be there.
        if tool == .ask {
            guard !ask.isEmpty else { throw NibAPIError.empty }
        } else {
            guard !text.isEmpty else { throw NibAPIError.empty }
        }

        let reply = try await send(payload(for: tool, text: text, ask: ask, options: options, prompt: prompt))

        // A superseded request must not overwrite a newer one's result.
        if Task.isCancelled { throw CancellationError() }

        try check(reply.status)

        guard let decoded = try? JSONDecoder().decode(Reply.self, from: reply.body) else {
            throw NibAPIError.network
        }

        let contents = (decoded.choices ?? []).compactMap { $0.message?.content }

        // Synonyms comes back as one completion listing several words, one per
        // line; every other tool returns one finished suggestion per choice.
        let raw = tool == .synonyms
            ? contents.flatMap { $0.split(whereSeparator: \.isNewline).map(String.init) }
            : contents

        let suggestions = raw
            .map(Self.clean)
            .filter { !$0.isEmpty }
            .uniqued()

        guard !suggestions.isEmpty else { throw NibAPIError.empty }
        return suggestions
    }

    /// Trims whitespace and stray wrapping quotes, and strips a leading list
    /// marker (`- `, `• `, `1. `, `1) `) that models add to synonym lines even
    /// when asked not to. What lands in the strip should be paste-ready.
    private static func clean(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .trimSet)
        s.replace(#/^\s*(?:[-*•]|\d+[.)])\s+/#, with: "")
        return s.trimmingCharacters(in: .trimSet)
    }

    // MARK: - Prompt

    /// The number of variants worth asking for. Rewrite and Tone are the ones
    /// where a strip of alternatives earns its space; a translation has one
    /// right answer, so a second choice is just latency and cost.
    private func choices(for tool: NibTool) -> Int {
        switch tool {
        case .rewrite, .tone: 3
        default: 1
        }
    }

    /// The instruction that turns a generic model into one tool.
    ///
    /// Every prompt ends the same way — return only the edited text, same
    /// language, no quotes or preamble — because the toolbar drops the result
    /// straight into the user's sentence. A model that explains itself would put
    /// "Here's a warmer version:" into someone's message.
    private func system(for tool: NibTool, options: ToolOptions, prompt: String?) -> String {
        let tail = "Preserve the original meaning and the language it is written in. "
            + "Reply with only the edited text — no quotation marks, no preamble, no explanation."

        switch tool {
        case .fix:
            return "Correct the spelling, grammar, and punctuation of the user's "
                + "message. Change nothing else — keep the wording, tone, and "
                + "meaning exactly as they are. \(tail)"
        case .rewrite:
            return "Rewrite the user's message so it reads more clearly and naturally. \(tail)"
        case .tone:
            // A custom preset arrives as a full instruction in `prompt`; a
            // built-in one arrives as its name in `options.tonePreset`.
            let tone = prompt?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? options.tonePreset
                ?? "warmer"
            return "Rewrite the user's message in a \(tone) tone. \(tail)"
        case .translate:
            let language = options.targetLanguage ?? "English"
            return "Translate the user's message into \(language). \(tail)"
        case .synonyms:
            // Not "edited text": a list. Its own instruction, so it must not
            // borrow `tail`, which would tell the model to return one line.
            return "Give 6 alternative words or short phrases for the user's "
                + "text — synonyms or near-synonyms — matching its part of speech "
                + "and register, in the same language. Reply with only the "
                + "alternatives, one per line, no numbering and no explanation."
        case .ask:
            // Answers a typed question and drops the answer into the field, so
            // it must be brief and preamble-free like the rest — but it is the
            // one tool that writes something new rather than editing what's there.
            return "You are a concise writing assistant inside a phone keyboard. "
                + "Answer the user's request directly, in plain text with no "
                + "preamble, short enough to drop straight into what they are "
                + "typing. If they gave surrounding text, use it as context."
        }
    }

    private func payload(
        for tool: NibTool,
        text: String,
        ask: String,
        options: ToolOptions,
        prompt: String?
    ) -> Payload {
        let system = Message(
            role: "system",
            content: system(for: tool, options: options, prompt: prompt)
        )

        var messages = [system]
        if tool == .ask {
            // The question is the instruction; the draft, if any, is context.
            if !text.isEmpty {
                messages.append(Message(role: "user", content: "What I'm writing:\n\(text)"))
            }
            messages.append(Message(role: "user", content: ask))
        } else {
            messages.append(Message(role: "user", content: text))
        }

        return Payload(model: model, messages: messages, n: choices(for: tool))
    }

    // MARK: - Request

    private func send(_ payload: Payload) async throws -> LiveAPIClient.HTTPReply {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            return try await transport(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NibAPIError.network
        }
    }

    private func check(_ status: Int) throws {
        switch status {
        case 200..<300:
            return
        case 401, 403:
            // A bad or missing key is ours to fix, not the user's — it must not
            // read as a connection problem they could waste time on.
            throw NibAPIError.notConfigured
        case 429:
            // OpenAI returns 429 both for rate limits and for an exhausted
            // billing quota; either way the honest thing to show is "slow down".
            throw NibAPIError.quotaExceeded
        default:
            throw NibAPIError.network
        }
    }

    // MARK: - Wire types

    private struct Payload: Encodable {
        let model: String
        let messages: [Message]
        let n: Int
        // `temperature` is deliberately not sent. The gpt-5 reasoning models
        // reject any value but the default (1) with a 400, and every other
        // model already defaults to 1 — so omitting it is the one choice that
        // works everywhere.
    }

    private struct Message: Encodable {
        let role: String
        let content: String
    }

    private struct Reply: Decodable {
        let choices: [Choice]?

        struct Choice: Decodable {
            let message: Message?
            struct Message: Decodable { let content: String? }
        }
    }

    // MARK: - Default transport

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        // What people type is the most sensitive thing this app handles; none of
        // it should outlive the process in a cache file.
        configuration.timeoutIntervalForRequest = OpenAIClient.timeout
        configuration.timeoutIntervalForResource = OpenAIClient.timeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    private static let urlSession: Transport = { request in
        let (data, response) = try await OpenAIClient.session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return LiveAPIClient.HTTPReply(status: status, body: data)
    }
}

private extension CharacterSet {
    /// Models like to wrap a one-liner in quotes even when told not to; strip
    /// those along with surrounding whitespace so the paste is clean.
    static let trimSet = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "\"'"))
}
