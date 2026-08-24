import Foundation

/// The v1 toolbar.
///
/// "Reply" ("a draft, from their last message") appears in the concept mockup
/// but is **cut from v1**: a keyboard extension can only read the text field
/// being typed into, and the other person's message is app UI that no public
/// API exposes. Shipping it would underdeliver on its own tagline. Revisit in
/// v1.5 with an explicit paste affordance.
public enum NibTool: String, CaseIterable, Identifiable, Sendable {
    case rewrite
    case tone
    case fix
    case translate
    case synonyms
    case ask

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rewrite: "Rewrite"
        case .tone: "Tone"
        case .fix: "Fix"
        case .translate: "Translate"
        case .synonyms: "Synonyms"
        case .ask: "Ask AI"
        }
    }

    /// Copy from the "Your AI Toolkit" onboarding screen.
    public var subtitle: String {
        switch self {
        case .rewrite: "Say it another way, instantly"
        case .tone: "Warmer, formal, or shorter"
        case .fix: "Grammar and spelling, explained"
        case .translate: "100+ languages, in place"
        case .synonyms: "The word on the tip of your tongue"
        case .ask: "Anything else — right above the keys"
        }
    }

    /// SF Symbol approximating the mockup's hand-drawn glyphs.
    public var symbol: String {
        switch self {
        case .rewrite: "pencil.line"
        case .tone: "target"
        case .fix: "sparkles"
        case .translate: "globe"
        case .synonyms: "arrow.left.arrow.right"
        case .ask: "bolt.fill"
        }
    }

    /// Whether the tool shows a second row of options when selected.
    public var hasSubOptions: Bool {
        self == .tone || self == .translate
    }
}
