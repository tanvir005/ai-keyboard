import AudioToolbox
import UIKit
import SwiftUI
import NibKit

/// The keyboard extension's entry point.
///
/// Responsibilities are deliberately thin: own the lifecycle, adapt
/// `UITextDocumentProxy` to `KeyboardTextInterface`, and host the SwiftUI tree.
/// All product logic lives in `ToolbarViewModel`; all prompt construction will
/// live server-side. This process runs under a tight memory ceiling, so
/// resist adding dependencies here — no analytics, no crash SDK, no HTTP lib.
final class KeyboardViewController: UIInputViewController {

    private var model: ToolbarViewModel!
    private var host: UIHostingController<KeyboardRootView>!
    private var heightConstraint: NSLayoutConstraint?

    /// Held rather than created per keystroke: the Taptic Engine needs warming,
    /// and a generator built at press time fires late enough to feel detached
    /// from the tap.
    private let impact = UIImpactFeedbackGenerator(style: .light)

    /// Hold-to-delete, shaped like the system keyboard: a pause so a normal tap
    /// is never mistaken for a hold, then steady character deletion, then whole
    /// words once the length of the hold makes it clear the user is clearing a
    /// field rather than correcting a typo.
    private enum DeleteRepeat {
        static let firstDelay: TimeInterval = 0.45
        static let interval: TimeInterval = 0.1
        /// ~1.8s of held delete before words start going.
        static let wordsAfterTicks = 18
        /// Words are bigger units, so they land at half the character cadence.
        static let wordEveryTicks = 2
    }

    private var deleteTimer: Timer?
    private var deleteTicks = 0

    /// Two spaces become ". " only when the second follows the first quickly.
    /// Timing it rather than reading the document alone leaves a deliberate
    /// double space — someone lining text up — intact.
    private static let doubleSpaceWindow: TimeInterval = 0.6
    private var lastSpaceAt: Date?

    private let spelling = SpellSuggestions()


    override func viewDidLoad() {
        super.viewDidLoad()

        model = ToolbarViewModel(text: self)

        let root = KeyboardRootView(
            model: model,
            onKey: { [weak self] in self?.handle($0) },
            onPress: { [weak self] in self?.feedback(for: $0) },
            onHoldBegin: { [weak self] in self?.beginRepeating($0) },
            onHoldEnd: { [weak self] _ in self?.cancelRepeating() },
            autoShift: { [weak self] in self?.shouldAutoCapitalize() ?? true },
            returnLabel: returnLabel(),
            needsGlobe: needsInputModeSwitchKey,
            suggestions: WordSuggestions(),
            onSuggestion: { [weak self] in self?.replaceCurrentWord(with: $0) },
            onKeepTyped: { [weak self] in self?.keepTypedWord($0) },
            onCursorBegin: { [weak self] in self?.beginCursorDrag() },
            onCursorMove: { [weak self] in self?.moveCursor(by: $0) },
            onAlternate: { [weak self] in self?.insertAlternate($0) },
            onHeightChange: { [weak self] in self?.updateHeight($0) }
        )

        host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 32pt suggestion strip + 44pt tool row + 226pt of keys. Fixed, and it
        // has to stay fixed: the input view does not resize in step with its
        // content, so a board that grows mid-typing overflows the space the
        // system gave it and clips at both ends.
        let height = view.heightAnchor.constraint(equalToConstant: 302)
        // Below required so the system can still resize us without conflicts.
        height.priority = .defaultHigh
        height.isActive = true
        heightConstraint = height
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The host app cannot read this itself — record it so Settings can
        // report Full Access state honestly, as of the last keyboard use.
        SharedSettings.shared.recordFullAccess(hasFullAccess)

        if SharedSettings.shared.hapticsEnabled, hasFullAccess {
            impact.prepare()
        }

        host.rootView.returnLabel = returnLabel()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        documentChanged()
    }

    /// Everything that has to be recomputed when the document moves under us.
    ///
    /// Called from `textDidChange` and after our own edits, because the two do
    /// not reliably cover each other — a caret moved by the user arrives only
    /// through the first, and the ordering of the second is ours to control.
    private func documentChanged() {
        // The keyboard outlives the field it was opened for: moving from a chat
        // box to a search box has to relabel return, or it keeps promising to
        // send something.
        let label = returnLabel()
        if host.rootView.returnLabel != label {
            host.rootView.returnLabel = label
        }

        let words = spelling.suggestions(before: contextBeforeCaret)
        if host.rootView.suggestions != words {
            host.rootView.suggestions = words
        }

    }

    /// Swaps the word under the caret for a tapped suggestion.
    ///
    /// Deletes by `Character` count so one call per grapheme cluster is made —
    /// the same reason `deleteWordBackward` counts that way.
    private func replaceCurrentWord(with replacement: String) {

        guard
            let before = contextBeforeCaret,
            let word = CurrentWord.trailing(in: before)
        else { return }

        for _ in 0 ..< word.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(replacement)

        feedback(for: .character(replacement))
        documentChanged()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // A keyboard dismissed mid-hold would otherwise leave the repeater
        // firing into a document that is no longer ours.
        cancelRepeating()
    }

    private func updateHeight(_ height: CGFloat) {
        guard height > 0, let constraint = heightConstraint else { return }
        guard abs(constraint.constant - height) > 1 else { return }
        constraint.constant = height
    }

    // MARK: - Press feedback

    /// Fires on touch-down, before the character is inserted.
    ///
    /// Both channels are gated on their Settings toggle. Haptics are gated on
    /// Full Access too: `UIFeedbackGenerator` is inert in an extension without
    /// it, so there is nothing to gain from warming the engine.
    private func feedback(for cap: KeyCap) {
        // Delete on an empty field removes nothing, so it must not sound or
        // feel as though it did. The click and the tap are a report that
        // something happened — firing them into an empty field is the keyboard
        // telling the user it deleted text that was not there.
        if case .backspace = cap, !hasTextToDelete { return }

        if SharedSettings.shared.soundEnabled {
            AudioServicesPlaySystemSound(Self.clickSound(for: cap))
        }

        if SharedSettings.shared.hapticsEnabled, hasFullAccess {
            impact.impactOccurred(intensity: 0.65)
            impact.prepare()
        }
    }

    /// The three sounds the system keyboard actually uses: a tap, a heavier
    /// delete, and a duller modifier.
    ///
    /// `playInputClick()` is the documented route and it was being called, but
    /// the system routes that request through the *input view* and asks it,
    /// via `UIInputViewAudioFeedback`, whether clicks are wanted. Conforming
    /// this controller did not put the conformance on the view the system
    /// asks, so every call was discarded in silence. These are the sounds that
    /// call would have played, requested directly.
    private static func clickSound(for cap: KeyCap) -> SystemSoundID {
        switch cap {
        case .backspace: 1155
        case .shift, .mode, .globe: 1156
        default: 1104
        }
    }

    // MARK: - Hold to repeat

    private func beginRepeating(_ cap: KeyCap) {
        guard cap.repeatsWhenHeld else { return }
        cancelRepeating()
        deleteTicks = 0

        // Two stages: a one-shot delay, which then installs the repeater. Both
        // go on the common run loop mode so a scrolling toolbar cannot stall
        // the deletion mid-hold.
        let starter = Timer(timeInterval: DeleteRepeat.firstDelay, repeats: false) { [weak self] _ in
            guard let self else { return }
            let repeater = Timer(timeInterval: DeleteRepeat.interval, repeats: true) { [weak self] _ in
                self?.repeatTick()
            }
            self.deleteTimer = repeater
            RunLoop.main.add(repeater, forMode: .common)
        }
        deleteTimer = starter
        RunLoop.main.add(starter, forMode: .common)
    }

    /// Whether there is anything behind the caret at all.
    private var hasTextToDelete: Bool {
        !(contextBeforeCaret ?? "").isEmpty
    }

    /// The document before the caret.
    private var contextBeforeCaret: String? {
        textDocumentProxy.documentContextBeforeInput
    }

    private func repeatTick() {
        // Once the field is empty the hold has nothing left to do. Stopping
        // here rather than ticking on also means the finger can stay down
        // without the keyboard clicking at an empty field.
        guard hasTextToDelete else {
            cancelRepeating()
            return
        }

        deleteTicks += 1

        if deleteTicks < DeleteRepeat.wordsAfterTicks {
            textDocumentProxy.deleteBackward()
        } else if deleteTicks % DeleteRepeat.wordEveryTicks == 0 {
            deleteWordBackward()
        } else {
            return // skipped tick — no feedback for a frame where nothing moved
        }

        feedback(for: .backspace)
    }

    private func cancelRepeating() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        deleteTicks = 0
        // Once, on release, rather than on every tick: running the spell
        // checker ten times a second through a hold is work nobody sees.
        documentChanged()
    }

    /// Deletes back over any trailing spaces and then the word before them.
    ///
    /// Counted in `Character`s rather than unicode scalars so `deleteBackward()`
    /// is called once per grapheme cluster — the same reason `TextContextResolver`
    /// counts that way. An emoji in the deleted span is one delete, not four.
    private func deleteWordBackward() {
        guard let before = contextBeforeCaret, !before.isEmpty else {
            textDocumentProxy.deleteBackward()
            return
        }

        var index = before.endIndex
        var count = 0

        while index > before.startIndex {
            let previous = before.index(before: index)
            guard before[previous].isWhitespace else { break }
            index = previous
            count += 1
        }

        while index > before.startIndex {
            let previous = before.index(before: index)
            guard !before[previous].isWhitespace else { break }
            index = previous
            count += 1
        }

        for _ in 0 ..< max(count, 1) {
            textDocumentProxy.deleteBackward()
        }
    }

    /// Turns a quick second space into ". ", and reports whether it did.
    ///
    /// Returns false for every case the rule does not cover, leaving the caller
    /// to insert an ordinary space — see `TypingRules` for which those are.
    private func promoteDoubleSpace() -> Bool {
        guard
            let last = lastSpaceAt,
            Date().timeIntervalSince(last) < Self.doubleSpaceWindow,
            let before = contextBeforeCaret,
            TypingRules.shouldPromoteSpaceToSentenceBreak(before: before)
        else { return false }

        textDocumentProxy.deleteBackward()
        textDocumentProxy.insertText(". ")
        // Cleared so a third space types a space rather than stacking stops.
        lastSpaceAt = nil
        return true
    }

    /// What the return key should say for the field being typed into.
    private func returnLabel() -> String {
        switch textDocumentProxy.returnKeyType {
        case .go: "Go"
        case .google, .yahoo, .search: "Search"
        case .join: "Join"
        case .next: "Next"
        case .route: "Route"
        case .send: "Send"
        case .done: "Done"
        case .emergencyCall: "Call"
        case .continue: "Continue"
        default: "return"
        }
    }

    /// Inserts the glyph chosen from a held key's alternates row.
    ///
    /// Separate from `handle` because the choice is made by the gesture rather
    /// than by which key was struck — the key that opened the row is not the
    /// character that ends up in the document.
    private func insertAlternate(_ glyph: String) {
        textDocumentProxy.insertText(glyph)
        feedback(for: .character(glyph))
        documentChanged()
    }

    // MARK: - Suggestions

    /// The user tapped the word they actually typed, keeping it as written.
    private func keepTypedWord(_ word: String) {
        spelling.keep(word)
        documentChanged()
    }

    // MARK: - Cursor dragging

    private func beginCursorDrag() {
        feedback(for: .space)
    }

    private func moveCursor(by offset: Int) {
        guard offset != 0 else { return }
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
    }

    // MARK: - Auto-capitalisation

    /// True when the caret sits where a capital belongs — an empty field, or the
    /// start of a new sentence.
    ///
    /// The shift state used to be set once, when the keyboard was created, and
    /// only ever turned off. Clearing a field left it lowercase because nothing
    /// ever asked this question again.
    private func shouldAutoCapitalize() -> Bool {
        guard let before = contextBeforeCaret else { return true }

        var index = before.endIndex
        var crossedSpace = false

        while index > before.startIndex {
            let previous = before.index(before: index)
            let character = before[previous]

            if character.isNewline { return true }
            if character.isWhitespace {
                crossedSpace = true
                index = previous
                continue
            }
            // A capital is due only after sentence-ending punctuation *and* a
            // space — otherwise "e.g" would capitalise mid-word.
            return crossedSpace && (character == "." || character == "!" || character == "?")
        }

        return true // nothing but whitespace behind the caret
    }

    // MARK: - Key handling

    private func handle(_ cap: KeyCap) {
        switch cap {
        case .character(let c):
            textDocumentProxy.insertText(c)
        case .space:
            if promoteDoubleSpace() { break }
            textDocumentProxy.insertText(" ")
            lastSpaceAt = Date()
        case .newline:
            textDocumentProxy.insertText("\n")
        case .backspace:
            textDocumentProxy.deleteBackward()
        case .globe:
            advanceToNextInputMode()
        case .emoji:
            break // the root view swaps in the emoji page
        case .shift, .mode:
            break // handled in the SwiftUI layer, which owns that state
        }

        documentChanged()
    }
}

// MARK: - KeyboardTextInterface

extension KeyboardViewController: KeyboardTextInterface {
    var documentBefore: String? { textDocumentProxy.documentContextBeforeInput }
    var documentAfter: String? { textDocumentProxy.documentContextAfterInput }

    func insertText(_ text: String) { textDocumentProxy.insertText(text) }
    func deleteBackward() { textDocumentProxy.deleteBackward() }
}

// MARK: - Root view

struct KeyboardRootView: View {
    @Bindable var model: ToolbarViewModel
    var onKey: (KeyCap) -> Void
    var onPress: (KeyCap) -> Void
    var onHoldBegin: (KeyCap) -> Void
    var onHoldEnd: (KeyCap) -> Void
    /// Asks the controller whether the caret is somewhere a capital belongs.
    /// The view cannot answer this itself — only the controller can see the
    /// document.
    var autoShift: () -> Bool
    var returnLabel: String
    var needsGlobe: Bool
    var suggestions: WordSuggestions
    var onSuggestion: (String) -> Void
    var onKeepTyped: (String) -> Void
    var onCursorBegin: () -> Void
    var onCursorMove: (Int) -> Void
    var onAlternate: (String) -> Void
    var onHeightChange: (CGFloat) -> Void

    @State private var mode: KeyboardMode = .letters
    @State private var shifted = true
    @State private var showingEmoji = false

    // 226 rather than 214: the key rows now sit 12pt lower to leave the press
    // balloon somewhere to go. Without matching that here the bottom row would
    // be pushed into the home indicator.
    private let keyAreaHeight: CGFloat = 226

    var body: some View {
        VStack(spacing: 0) {
            // Always present. See SuggestionStrip for why it cannot come and go.
            SuggestionStrip(
                suggestions: suggestions,
                onPick: onSuggestion,
                onKeepTyped: onKeepTyped
            )
            AccessoryBarView(model: model)

            if showingEmoji {
                EmojiPageView(
                    onEmoji: { glyph in
                        onAlternate(glyph)
                        shifted = autoShift()
                    },
                    onBackspace: {
                        onKey(.backspace)
                        shifted = autoShift()
                    },
                    onLetters: { showingEmoji = false },
                    onPress: { onPress(.character("")) }
                )
                .frame(height: keyAreaHeight)
            } else {
                KeyboardView(
                    mode: mode,
                    shifted: shifted,
                    returnLabel: returnLabel,
                    needsGlobe: needsGlobe,
                    onKey: handle,
                    onPress: onPress,
                    onHoldBegin: onHoldBegin,
                    onHoldEnd: { cap in
                        onHoldEnd(cap)
                        // A held delete bypasses `handle`, so this is the only
                        // place shift can be re-evaluated after one clears the
                        // field.
                        shifted = autoShift()
                    },
                    onAlternate: { glyph in
                        // Same reasoning: an alternate is inserted straight from
                        // the gesture, so it never passes through `handle`.
                        onAlternate(glyph)
                        shifted = autoShift()
                    },
                    onCursorBegin: onCursorBegin,
                    onCursorMove: onCursorMove
                )
                .frame(height: keyAreaHeight)
            }
        }
        .onAppear {
            // The field may already contain text — starting shifted regardless
            // capitalises the middle of somebody's sentence.
            shifted = autoShift()
        }
        .background(NibStyle.Palette.keyboardBackground)
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: KeyboardHeightKey.self, value: geo.size.height)
            }
        }
        .onPreferenceChange(KeyboardHeightKey.self) { onHeightChange($0) }
    }

    /// Shift and page switching are view state; everything else is a document
    /// edit and goes to the controller.
    private func handle(_ cap: KeyCap) {
        switch cap {
        case .shift:
            shifted.toggle()
        case .emoji:
            showingEmoji = true
        case .mode(let next):
            mode = next
            shifted = next == .letters ? autoShift() : false
        case .space, .newline:
            onKey(cap)
            // A break ends the run of numbers or symbols the page was switched
            // for. The stock keyboard returns here on its own, and without it
            // every figure typed mid-sentence costs a second trip back to ABC.
            mode = .letters
            shifted = autoShift()
        case .character(let character):
            onKey(cap)
            if TypingRules.returnsToLetters(after: character) { mode = .letters }
            // Auto-unshift after a capital, and auto-shift again at the start of
            // the next sentence — one rule covers both, because it asks where
            // the caret actually is rather than tracking what was typed.
            shifted = autoShift()
        case .backspace:
            onKey(cap)
            shifted = autoShift()
        default:
            onKey(cap)
        }
    }
}

private struct KeyboardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
