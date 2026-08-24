import Foundation

/// Canned suggestions so the whole app is usable before the backend exists.
///
/// The transforms are intentionally crude string manipulation — the point is
/// that tapping a tool returns *something derived from what you actually typed*,
/// so the interaction loop can be felt and critiqued. Nothing here is meant to
/// survive; `LiveAPIClient` replaces it wholesale in Phase 1.
public struct StubAPIClient: NibAPIClient {

    /// Simulated round-trip. Long enough to prove the keyboard never blocks.
    public var latency: Duration

    public init(latency: Duration = .milliseconds(650)) {
        self.latency = latency
    }

    public func suggest(
        tool: NibTool,
        scope: TextScope,
        options: ToolOptions,
        prompt: String?
    ) async throws -> [String] {
        let source = scope.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty || tool == .ask else { throw NibAPIError.empty }

        try? await Task.sleep(for: latency)
        if Task.isCancelled { throw CancellationError() }

        return switch tool {
        case .fix: Self.fix(source)
        case .rewrite: Self.rewrite(source)
        case .tone: Self.tone(source, preset: options.tonePreset ?? "Warmer")
        case .translate: Self.translate(source, to: options.targetLanguage ?? "Spanish")
        case .synonyms: Self.synonyms(source)
        case .ask: Self.ask(source, prompt: prompt)
        }
    }

    // MARK: - Transforms

    private static func fix(_ s: String) -> [String] {
        var fixed = s
        let corrections = [
            "i ": "I ", " i ": " I ", "dont": "don't", "cant": "can't",
            "wont": "won't", "im ": "I'm ", "ive ": "I've ", "teh ": "the ",
            "recieve": "receive", "seen the": "have seen the", "alot": "a lot",
        ]
        for (wrong, right) in corrections {
            fixed = fixed.replacingOccurrences(of: wrong, with: right, options: .caseInsensitive)
        }
        fixed = fixed.prefix(1).uppercased() + fixed.dropFirst()
        if let last = fixed.last, !".!?".contains(last) { fixed += "." }
        return [fixed, fixed.replacingOccurrences(of: ".", with: "!")].uniqued()
    }

    private static func rewrite(_ s: String) -> [String] {
        [
            "Here's another way to put it: \(s.lowercasedFirst())",
            "\(s.capitalizedFirst()) — put more directly.",
            "To rephrase: \(s.lowercasedFirst())",
        ]
    }

    private static func tone(_ s: String, preset: String) -> [String] {
        switch preset.lowercased() {
        case "professional":
            ["I wanted to let you know that \(s.lowercasedFirst()).",
             "Following up: \(s.lowercasedFirst())."]
        case "concise", "shorter":
            [String(s.split(separator: " ").prefix(6).joined(separator: " ")),
             s.split(separator: " ").prefix(4).joined(separator: " ") + "…"]
        case "friendly":
            ["Hey! \(s.capitalizedFirst()) 😊", "\(s.capitalizedFirst()) — hope that works!"]
        default: // Warmer
            ["so sorry — \(s.lowercasedFirst())!",
             "\(s.capitalizedFirst()) — really sorry about that.",
             "ah, \(s.lowercasedFirst()) — can we find another time?"]
        }
    }

    private static func translate(_ s: String, to language: String) -> [String] {
        ["[\(language)] \(s)", "[\(language), informal] \(s.lowercasedFirst())"]
    }

    private static func synonyms(_ s: String) -> [String] {
        let last = s.split(separator: " ").last.map(String.init) ?? s
        return ["\(last) → alternative", "\(last) → substitute", "\(last) → replacement"]
    }

    private static func ask(_ s: String, prompt: String?) -> [String] {
        let ask = prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !ask.isEmpty else { return ["Ask me anything about what you're writing."] }
        return [
            "• \(ask.capitalizedFirst())\n• Based on: \(s.prefix(40))…\n• (stubbed response)",
            "Short answer to \"\(ask)\" — this is placeholder text until the backend is wired up.",
        ]
    }
}

// MARK: - Small string helpers

extension String {
    func capitalizedFirst() -> String { prefix(1).uppercased() + dropFirst() }
    func lowercasedFirst() -> String { prefix(1).lowercased() + dropFirst() }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
