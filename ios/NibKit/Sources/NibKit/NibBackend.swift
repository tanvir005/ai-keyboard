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

    /// Tools routed to the live service. Everything else stays stubbed.
    public static let liveTools: Set<NibTool> = [.fix]

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

    public static var isConfigured: Bool { baseURL != nil }

    // MARK: - Building the client

    /// The client the keyboard should use.
    ///
    /// Unconfigured builds get the stub for everything, which is why this is
    /// safe to wire in before any deployment exists: nothing changes until a
    /// URL is set, and then only the tools in `liveTools` change.
    public static func makeClient(
        fallback: any NibAPIClient = StubAPIClient(),
        tools: Set<NibTool> = liveTools
    ) -> any NibAPIClient {
        guard let baseURL else { return fallback }
        return RoutedAPIClient(
            live: LiveAPIClient(baseURL: baseURL, secret: appSecret),
            fallback: fallback,
            liveTools: tools
        )
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
