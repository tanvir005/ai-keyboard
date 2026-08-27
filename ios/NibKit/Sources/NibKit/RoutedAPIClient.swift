import Foundation

/// Sends some tools to one client and the rest to another.
///
/// This exists so the backend can be switched on **one tool at a time**. Fix is
/// first because it is the one with a mostly-right answer: spelling and grammar
/// can be judged correct or not, so a bad model shows up immediately. Rewrite
/// and Tone are matters of taste, and "is this better?" is not a question a
/// first integration should have to answer.
///
/// The rest keep returning canned text, which is visibly canned — nobody will
/// mistake a stub for a live answer while testing.
public struct RoutedAPIClient: NibAPIClient {

    private let live: any NibAPIClient
    private let fallback: any NibAPIClient
    private let liveTools: Set<NibTool>

    public init(
        live: any NibAPIClient,
        fallback: any NibAPIClient = StubAPIClient(),
        liveTools: Set<NibTool>
    ) {
        self.live = live
        self.fallback = fallback
        self.liveTools = liveTools
    }

    public func suggest(
        tool: NibTool,
        scope: TextScope,
        options: ToolOptions,
        prompt: String?
    ) async throws -> [String] {
        let client = liveTools.contains(tool) ? live : fallback
        return try await client.suggest(
            tool: tool, scope: scope, options: options, prompt: prompt
        )
    }
}
