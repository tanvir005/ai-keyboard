import Foundation

/// Options a tool may carry. Mirrors the planned backend contract:
/// `{ text, context?, options? }`.
public struct ToolOptions: Codable, Equatable, Sendable {
    public var tonePreset: String?
    public var targetLanguage: String?

    public init(tonePreset: String? = nil, targetLanguage: String? = nil) {
        self.tonePreset = tonePreset
        self.targetLanguage = targetLanguage
    }

    public static let none = ToolOptions()
}

public struct ToolContext: Codable, Equatable, Sendable {
    public var before: String?
    public var after: String?
}

public struct ToolRequest: Codable, Sendable {
    public var text: String
    public var context: ToolContext?
    public var options: ToolOptions?
}

public struct Usage: Codable, Equatable, Sendable {
    public var used: Int
    /// `nil` means unlimited (Pro).
    public var limit: Int?
    public var resetsAt: Date?
}

public struct ToolResponse: Codable, Sendable {
    public var suggestions: [String]
    public var usage: Usage?
}

public enum NibAPIError: Error, Equatable, Sendable {
    case quotaExceeded
    case noFullAccess
    case network
    case empty
    /// The service is reachable but refused us — no URL set for this build, or
    /// a key it does not accept. Ours to fix, not the user's, so it must not read
    /// as a connection problem they could waste time troubleshooting.
    case notConfigured

    public var userMessage: String {
        switch self {
        case .quotaExceeded: "You've used all 15 edits today."
        case .noFullAccess: "Turn on Full Access to use Nib's tools."
        case .network: "Couldn't reach Nib. Check your connection."
        case .empty: "Type something first."
        case .notConfigured: "Nib's AI isn't set up on this build yet."
        }
    }
}

/// The seam between the keyboard and whatever is producing suggestions.
///
/// Two conform to it: `StubAPIClient`, which invents suggestions locally, and
/// `LiveAPIClient`, which asks Nib's own service. `RoutedAPIClient` splits
/// traffic between them per tool — see `NibBackend.makeClient()`. The UI has
/// never known which it is talking to, which is what makes switching a
/// one-line change.
public protocol NibAPIClient: Sendable {
    func suggest(
        tool: NibTool,
        scope: TextScope,
        options: ToolOptions,
        prompt: String?
    ) async throws -> [String]
}
