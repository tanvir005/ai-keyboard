import Foundation
import Observation
import NibKit

/// What the keyboard needs from the host text field. Keeps the SwiftUI layer
/// free of `UIInputViewController`, and makes the view model testable.
protocol KeyboardTextInterface: AnyObject {
    var documentBefore: String? { get }
    var documentAfter: String? { get }
    var hasFullAccess: Bool { get }
    func insertText(_ text: String)
    func deleteBackward()
    func advanceToNextInputMode()
}

/// Drives the AI toolbar above the keys.
///
/// The single most important property here: **nothing in this class blocks key
/// input**. Requests run in a detached task and only ever mutate `state`, which
/// is rendered by the accessory bar. Keys keep working while a request is in
/// flight — competitor 1-star reviews are dominated by keyboard lag, and this
/// is the structural reason Nib won't have it.
@MainActor
@Observable
final class ToolbarViewModel {

    enum State: Equatable {
        case idle
        case loading
        case suggestions([String])
        case error(NibAPIError)
    }

    var state: State = .idle
    var selectedTool: NibTool?
    var tonePreset: TonePreset = .warmer
    var targetLanguage: String = "Spanish"
    var askPrompt: String = ""

    /// The scope sent to the AI. Kept so `accept` deletes exactly what was
    /// sent — the invariant that makes replacement work without a selection API.
    private(set) var activeScope: TextScope = .empty

    private weak var text: KeyboardTextInterface?
    private let client: NibAPIClient
    private let settings: SharedSettings
    private var inFlight: Task<Void, Never>?

    init(
        text: KeyboardTextInterface?,
        client: NibAPIClient = NibBackend.makeClient(),
        settings: SharedSettings = .shared
    ) {
        self.text = text
        self.client = client
        self.settings = settings
    }

    var tonePresets: [TonePreset] { settings.tonePresets }

    var hasFullAccess: Bool { text?.hasFullAccess ?? false }

    // MARK: - Tool selection

    func select(_ tool: NibTool) {
        if selectedTool == tool {
            selectedTool = nil
            reset()
            return
        }
        selectedTool = tool
        state = .idle
        // Tools with sub-options wait for the user to pick one; the rest fire
        // straight away, which is the whole "one tap above the keys" promise.
        if !tool.hasSubOptions && tool != .ask {
            run(tool)
        }
    }

    func selectTone(_ preset: TonePreset) {
        tonePreset = preset
        run(.tone)
    }

    func selectLanguage(_ language: String) {
        targetLanguage = language
        run(.translate)
    }

    func submitAsk() {
        guard !askPrompt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        run(.ask)
    }

    func regenerate() {
        guard let tool = selectedTool else { return }
        run(tool)
    }

    func reset() {
        inFlight?.cancel()
        inFlight = nil
        state = .idle
        activeScope = .empty
    }

    // MARK: - Running a tool

    private func run(_ tool: NibTool) {
        // Single-flight: a second tap supersedes the first rather than racing it.
        inFlight?.cancel()

        guard let text else { return }

        guard text.hasFullAccess else {
            state = .error(.noFullAccess)
            return
        }
        guard !settings.isQuotaExhausted else {
            state = .error(.quotaExceeded)
            return
        }

        let scope = TextContextResolver.resolve(
            before: text.documentBefore,
            after: text.documentAfter,
            readFullDraft: settings.readFullDraft
        )
        guard !scope.isEmpty || tool == .ask else {
            state = .error(.empty)
            return
        }
        activeScope = scope

        let options = ToolOptions(
            tonePreset: tool == .tone ? tonePreset.name : nil,
            targetLanguage: tool == .translate ? targetLanguage : nil
        )
        let prompt = tool == .ask ? askPrompt : (tonePreset.isBuiltIn ? nil : tonePreset.instruction)

        state = .loading
        // The class is @MainActor, so this task inherits main-actor isolation:
        // assignments to `state` are already on the right actor, and the
        // cancellation checks keep a superseded request from overwriting a
        // newer one's result.
        inFlight = Task { [weak self, client] in
            do {
                let suggestions = try await client.suggest(
                    tool: tool, scope: scope, options: options, prompt: prompt
                )
                guard let self, !Task.isCancelled else { return }
                state = suggestions.isEmpty ? .error(.empty) : .suggestions(suggestions)
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                state = .error((error as? NibAPIError) ?? .network)
            }
        }
    }

    // MARK: - Accepting a suggestion

    /// Replaces the scope with `suggestion`.
    ///
    /// There is no selection-replace API for keyboard extensions, so this
    /// deletes exactly as many characters as were sent and types the
    /// replacement in their place. `deleteCount` counts grapheme clusters, so
    /// emoji and combining marks are removed as single units.
    func accept(_ suggestion: String) {
        guard let text else { return }

        for _ in 0..<activeScope.deleteCount {
            text.deleteBackward()
        }
        text.insertText(suggestion)

        settings.consumeQuota()
        EditHistoryLog.append(
            EditRecord(
                tool: selectedTool ?? .rewrite,
                sourceApp: nil,
                before: activeScope.text,
                after: suggestion
            )
        )

        selectedTool = nil
        askPrompt = ""
        reset()
    }
}
