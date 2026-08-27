import Foundation

/// Where the AI comes from, and whether it is switched on yet.
///
/// Both values come from the bundle's `Info.plist`, which XcodeGen fills from
/// build settings (`NIB_API_BASE_URL`, `NIB_APP_SECRET`). That means a
/// deployment is configured in one place, per build, without a code change —
/// and that a build with neither set still runs, on stubs, exactly as it does
/// today.
public enum NibBackend {

    public static let baseURLKey = "NibAPIBaseURL"
    public static let appSecretKey = "NibAppSecret"
    public static let openAIKeyKey = "NibOpenAIKey"
    public static let openAIModelKey = "NibOpenAIModel"

    /// Tools routed to Nib's own service.
    ///
    /// Empty for now: the app talks to OpenAI directly (see `openAITools`) and
    /// the Vercel service is set aside, not called. The `LiveAPIClient` /
    /// `RoutedAPIClient` wiring is kept intact so switching back is a one-line
    /// change — put `.fix` (or whatever the service should own) back here.
    public static let liveTools: Set<NibTool> = []

    /// Tools routed straight to OpenAI when a build carries a key.
    ///
    /// Every real tool: the taste-based edits (rewrite, tone, translate), Fix,
    /// and now Synonyms and Ask. With the backend set aside, OpenAI is the only
    /// thing that produces a real answer — anything left off this list falls
    /// through to the visibly-canned stub.
    public static let openAITools: Set<NibTool> = [
        .rewrite, .tone, .translate, .fix, .synonyms, .ask,
    ]

    // MARK: - Configuration

    public static var baseURL: URL? {
        url(from: string(for: baseURLKey))
    }

    /// Sent as `x-nib-key`.
    ///
    /// This is **not** authentication and should not be described as it. It
    /// ships inside the app, so anybody willing to unpack an IPA can read it.
    /// What it buys is that an endpoint found by a scanner is not an endpoint
    /// that can be drained by a scanner. A person who means it walks straight
    /// through. Device attestation is what replaces this when there is
    /// something worth protecting.
    public static var appSecret: String? {
        string(for: appSecretKey)
    }

    /// The OpenAI API key, read from `NibOpenAIKey`. Ships inside the app — see
    /// `OpenAIClient` for the trade-off this accepts.
    public static var openAIKey: String? {
        string(for: openAIKeyKey)
    }

    /// The model id sent to OpenAI, e.g. `gpt-4o-mini`. Configurable per build so
    /// the provider can be tuned without a code change; falls back to a widely
    /// available default when unset.
    public static var openAIModel: String {
        string(for: openAIModelKey) ?? OpenAIClient.defaultModel
    }

    public static var isConfigured: Bool { baseURL != nil || openAIKey != nil }

    // MARK: - Building the client

    /// The client the keyboard should use.
    ///
    /// Composed from what the build is configured for, each layer falling
    /// through to the next when its config is absent:
    ///
    /// - `openAITools` → OpenAI directly, when `NibOpenAIKey` is set.
    /// - `liveTools` (Fix) → Nib's own service, when `NibAPIBaseURL` is set.
    /// - everything else → the fallback stub.
    ///
    /// An unconfigured build sets neither and gets the stub for every tool,
    /// exactly as it did before any backend existed.
    public static func makeClient(
        fallback: any NibAPIClient = StubAPIClient()
    ) -> any NibAPIClient {
        var client = fallback

        // Nib's own service, when a base URL is set AND some tool is assigned to
        // it. `liveTools` is empty today, so this layer is skipped and the
        // service is never called — the URL can stay configured, dormant, until
        // a tool is handed back to it.
        if let baseURL, !liveTools.isEmpty {
            client = RoutedAPIClient(
                live: LiveAPIClient(baseURL: baseURL, secret: appSecret),
                fallback: client,
                liveTools: liveTools
            )
        }

        // Rewrite / Tone / Translate route straight to OpenAI when a key is set.
        // Layered outermost so it wins for its tools regardless of the above.
        if let openAIKey {
            client = RoutedAPIClient(
                live: OpenAIClient(apiKey: openAIKey, model: openAIModel),
                fallback: client,
                liveTools: openAITools
            )
        }

        return client
    }

    // MARK: - Reading Info.plist

    private static func string(for key: String) -> String? {
        clean(Bundle.main.object(forInfoDictionaryKey: key) as? String)
    }

    /// Empty and *unexpanded* values both mean "not set".
    ///
    /// The second case is the one that would otherwise waste an afternoon: if
    /// the build setting is undefined, Xcode leaves the literal `$(NAME)` in
    /// the plist, and a URL built from that string parses happily and fails at
    /// request time with something unrelated-looking.
    static func clean(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !trimmed.hasPrefix("$(")
        else { return nil }
        return trimmed
    }

    /// Parses a configured base URL, refusing ones that would send typed text
    /// in cleartext.
    ///
    /// Plain `http` is allowed for loopback only, so the service can be run
    /// locally during development. Anywhere else it is rejected rather than
    /// silently honoured — this app's payload is the sentence somebody is in
    /// the middle of writing.
    static func url(from raw: String?) -> URL? {
        guard let raw = clean(raw),
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              url.host != nil
        else { return nil }

        switch scheme {
        case "https":
            return url
        case "http":
            let host = url.host?.lowercased()
            return (host == "localhost" || host == "127.0.0.1") ? url : nil
        default:
            return nil
        }
    }
}
