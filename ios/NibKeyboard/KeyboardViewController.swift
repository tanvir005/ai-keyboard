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
    private let nextWords = NextWordStore()

    /// The last thing that was in the field, kept so the final word can still
    /// be learned after the field empties.
    ///
    /// A send leaves nothing behind to read — by the time we notice, the text
    /// is gone. So it is remembered on the way past.
    private var trailingSnapshot: String?

    /// Distinguishes a message being sent from one being deleted.
    ///
    /// Both end with an empty field, but only one of them means the user
    /// finished the word. Someone who backspaces out of "Assalamualaik" has
    /// abandoned it, and learning it would poison the table with half-words.
    private var lastKeyWasDelete = false

    /// A short coalescing delay before the strip leaves.
    ///
    /// Narrowing the predictions removes most of the reason the strip used to
    /// blink, so this no longer has to cover a two-keystroke gap — it only
    /// absorbs a single frame where one source has run out and the next has not
    /// answered yet. Long enough to stop a flicker, short enough that the strip
    /// never feels like it is lagging behind the typing.
    private static let suggestionLinger: TimeInterval = 0.18

    /// One duration for the strip's fade and the board's resize. They are the
    /// same movement seen from two places, and any difference between them
    /// reads as the keyboard coming apart.
    static let resizeDuration: TimeInterval = 0.22
    private var hideSuggestions: DispatchWorkItem?

    /// What the learned table last offered, kept so the letters of the next
    /// word can narrow it instead of discarding it. See `documentChanged`.
    private var offered: [String] = []

    /// The toolbar is the one part of the board with an unknown height — it
    /// grows a title row when a tool is selected. Everything else is constant,
    /// so this is all the controller needs in order to compute the rest.
    private var barHeight: CGFloat = 44


    /// Asks for the system's own keyboard backdrop rather than painting one.
    ///
    /// Matching the strip below the board by colour could not work: that strip
    /// is not a colour. It is a translucent material sampling whatever is
    /// behind it, which is why it looked warm over one app's cream background
    /// and neutral over another's white, and why every fixed grey tried so far
    /// was visibly a different surface.
    ///
    /// `.keyboard` is the same style the system uses for that strip, so the two
    /// match by construction instead of by resemblance — and go on matching in
    /// the dark, and in whatever Apple changes next, because it is one material
    /// rather than two guesses at it.
    override func loadView() {
        view = UIInputView(frame: .zero, inputViewStyle: .keyboard)
    }

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
            onBarHeight: { [weak self] in self?.barHeightChanged($0) }
        )

        // Nothing painted here: `loadView` asked for the keyboard material and
        // covering it would defeat the point.
        view.backgroundColor = .clear

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

        // The resting height: 44pt tool row + 226pt of keys, no strip. It grows
        // by the strip's 32pt when there is something to suggest.
        //
        // The key area is a fixed 226 and stays that way. Letting it give way
        // was worse than it sounds: SwiftUI found it could fit the strip by
        // squashing the keys, so the board never asked the system for more
        // height at all — the keys silently paid for the strip. Fixed, the
        // content has one honest ideal height and the board grows to match.
        let height = view.heightAnchor.constraint(equalToConstant: 270)
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

        noticeFieldEmptying()

        let context = contextBeforeCaret ?? ""

        // Between words: ask the learned table what usually comes next, and
        // keep the answer. The first letters of the next word will narrow it
        // rather than throw it away.
        guard let word = CurrentWord.trailing(in: context) else {
            offered = nextWords.predictions(
                after: CurrentWord.preceding(in: context, limit: 2),
                // Three, not two: with no typed word to show, the strip has a
                // whole slot free.
                limit: 3
            )
            publish(offered.isEmpty ? WordSuggestions() : WordSuggestions(typed: "", candidates: offered))
            return
        }

        // The predictions that were on offer a moment ago, narrowed to the ones
        // still consistent with what has been typed since.
        //
        // This is what stops the strip blinking. The dictionary says nothing
        // about a one- or two-letter word — too many candidates to mean
        // anything — so the strip used to empty at the start of every word and
        // refill two keystrokes later. Carrying the prediction through those
        // keystrokes removes the gap rather than timing around it, and the
        // suggestion it carries is a better one: a phrase this person actually
        // writes, not a word that merely starts the same way.
        let narrowed = offered.filter {
            $0.count > word.count && $0.lowercased().hasPrefix(word.lowercased())
        }

        let fromDictionary = spelling.suggestions(before: context)

        guard !narrowed.isEmpty else {
            publish(fromDictionary)
            return
        }

        var seen = Set<String>()
        let merged = (narrowed + fromDictionary.candidates)
            .filter { seen.insert($0.lowercased()).inserted }
            .prefix(2)

        publish(WordSuggestions(typed: word, candidates: Array(merged)))
    }

    /// Suggestions appear at once and leave on a delay.
    ///
    /// Ordinary typing crosses in and out of having something to offer several
    /// times within a single word. Hiding the moment there is nothing makes the
    /// row strobe, and a strip that flashes under the thumb is more
    /// distracting than one that simply sits there. Arriving late would be
    /// worse than useless, so only the departure waits.
    private func publish(_ words: WordSuggestions) {
        hideSuggestions?.cancel()
        hideSuggestions = nil

        guard words.isEmpty else {
            if host.rootView.suggestions != words {
                host.rootView.suggestions = words
                // Asked for in the same breath as the content changes, so the
                // board is never briefly the wrong size for what is in it.
                applyHeight()
            }
            return
        }

        guard !host.rootView.suggestions.isEmpty else { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.host.rootView.suggestions = WordSuggestions()
            self.applyHeight()
        }
        hideSuggestions = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.suggestionLinger, execute: work)
    }

    /// Swaps the word under the caret for a tapped suggestion.
    ///
    /// Deletes by `Character` count so one call per grapheme cluster is made —
    /// the same reason `deleteWordBackward` counts that way.
    private func replaceCurrentWord(with replacement: String) {
        if let before = contextBeforeCaret, let word = CurrentWord.trailing(in: before) {
            for _ in 0 ..< word.count {
                textDocumentProxy.deleteBackward()
            }
            textDocumentProxy.insertText(replacement)
        } else {
            // A prediction rather than a correction: there is no half-typed word
            // to swap out, so it goes in with the space that was going to follow
            // it anyway. Taking one is also a vote for it.
            textDocumentProxy.insertText(replacement + " ")
            learnFinishedWord()
        }

        feedback(for: .character(replacement))
        documentChanged()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // A keyboard dismissed mid-hold would otherwise leave the repeater
        // firing into a document that is no longer ours.
        cancelRepeating()
        // The keyboard is leaving with text still in the field: this is the
        // last chance to learn the word the user stopped on.
        hideSuggestions?.cancel()
        harvestTrailingWord()
        // Writes are batched, so this is where the last few are kept rather
        // than lost with the process.
        nextWords.save()
    }

    private func barHeightChanged(_ height: CGFloat) {
        guard height > 0, abs(barHeight - height) > 1 else { return }
        barHeight = height
        applyHeight()
    }

    /// Sets the board's height from what it is made of, rather than measuring
    /// the result and reacting.
    ///
    /// Everything but the toolbar is a known constant, so the total can be
    /// worked out at the moment the content changes and requested in the same
    /// breath. Measuring afterwards meant the board spent a beat at the wrong
    /// size on every appearance of the strip — which is the beat the keys used
    /// to move in.
    private func applyHeight() {
        let strip = host.rootView.suggestions.isEmpty ? 0 : SuggestionStrip.height
        let total = barHeight + KeyboardRootView.keyAreaHeight + strip

        guard let constraint = heightConstraint else { return }
        guard abs(constraint.constant - total) > 1 else { return }

        constraint.constant = total

        // Matched to the strip's own fade so the board and its contents move
        // as one thing. Left unanimated, the keyboard snaps to its new size
        // while the strip is still fading in, and the keys jump under the
        // thumb — which is the part that reads as disruptive, more than the
        // strip appearing at all.
        UIView.animate(withDuration: Self.resizeDuration) {
            self.view.superview?.layoutIfNeeded()
        }
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
        lastKeyWasDelete = true
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

    /// Watches for the field going empty, which is what a send looks like from
    /// in here — and takes the last word with it on the way out.
    private func noticeFieldEmptying() {
        let current = contextBeforeCaret ?? ""

        if current.isEmpty {
            // Emptied by a delete is somebody changing their mind, not
            // finishing a sentence.
            if trailingSnapshot != nil, !lastKeyWasDelete {
                harvestTrailingWord()
            }
            trailingSnapshot = nil
        } else {
            trailingSnapshot = current
        }

        lastKeyWasDelete = false
    }

    /// Learns the word the caret is still sitting on.
    ///
    /// `learnFinishedWord` only ever sees words a separator has closed, which
    /// silently excluded the last word of every message — nobody types a
    /// trailing space before pressing send, and that word is the one most worth
    /// predicting. This is the other half: called when the message leaves, not
    /// when the next word begins.
    private func harvestTrailingWord() {
        guard let context = trailingSnapshot ?? contextBeforeCaret else { return }
        guard let word = CurrentWord.trailing(in: context) else { return }

        nextWords.learn(
            previous: CurrentWord.preceding(in: context, limit: 2),
            next: word,
            in: textDocumentProxy
        )
        trailingSnapshot = nil
    }

    /// Feeds the word just completed, and the two before it, to the learned
    /// table. The store decides whether this field is one we may remember.
    private func learnFinishedWord() {
        guard let context = contextBeforeCaret else { return }

        let words = CurrentWord.preceding(in: context, limit: 3)
        guard let finished = words.last else { return }

        nextWords.learn(
            previous: Array(words.dropLast()),
            next: finished,
            in: textDocumentProxy
        )
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
            // Punctuation ends a word as surely as a space does, and "hello!"
            // is a whole message.
            if TypingRules.finishesAWord(c) { learnFinishedWord() }
        case .space:
            if promoteDoubleSpace() { break }
            textDocumentProxy.insertText(" ")
            lastSpaceAt = Date()
            // A space is what finishes a word, so it is the only moment we know
            // one is complete enough to be worth remembering.
            learnFinishedWord()
        case .newline:
            // Return is Send in most of the apps this keyboard lives in, so the
            // word before it is the last thing typed — and the last chance to
            // learn it.
            harvestTrailingWord()
            textDocumentProxy.insertText("\n")
            learnFinishedWord()
        case .backspace:
            lastKeyWasDelete = true
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
    var onBarHeight: (CGFloat) -> Void

    @State private var mode: KeyboardMode = .letters
    @State private var shifted = true
    @State private var showingEmoji = false

    // 226 rather than 214: the key rows now sit 12pt lower to leave the press
    // balloon somewhere to go. Without matching that here the bottom row would
    // be pushed into the home indicator.
    /// A ceiling, not a fixed size. The toolbar above grows a title row when a
    /// tool is selected, and a fixed height here pushes the bottom key row off
    /// the input view entirely — where it cannot be tapped at all.
    static let keyAreaHeight: CGFloat = 226
    private var keyAreaHeight: CGFloat { Self.keyAreaHeight }

    var body: some View {
        VStack(spacing: 0) {
            if !suggestions.isEmpty {
                SuggestionStrip(
                    suggestions: suggestions,
                    onPick: onSuggestion,
                    onKeepTyped: onKeepTyped
                )
                .transition(.opacity)
            }
            // The only part of the board whose height is not known in advance:
            // it grows a title row when a tool is selected. Measuring just this
            // — rather than the whole board — is what lets the controller
            // compute the total instead of waiting to be told it.
            AccessoryBarView(model: model)
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(key: BarHeightKey.self, value: geo.size.height)
                    }
                }
                .onPreferenceChange(BarHeightKey.self) { onBarHeight($0) }

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
        // Only the strip's own arrival and departure are animated, keyed on
        // whether there is anything to show. Animating on the words themselves
        // would cross-fade the row every time a keystroke changed a suggestion,
        // which is movement where the user is trying to read.
        .animation(.easeOut(duration: KeyboardViewController.resizeDuration), value: suggestions.isEmpty)
        .onAppear {
            // The field may already contain text — starting shifted regardless
            // capitalises the middle of somebody's sentence.
            shifted = autoShift()
        }
        // Anchored to the bottom, and this is the whole of why the keys used to
        // move. The host view is pinned top and bottom, so between the moment
        // the strip appears and the moment the system grants the extra height,
        // the content is taller than the box holding it — and SwiftUI centres
        // what overflows. Centred, 302pt of board in a 270pt box spilled 16pt
        // off each end: the keys slid down by 16 and the suggestion text was
        // sliced along the top. Both complaints, one cause.
        //
        // Bottom-aligned, the overflow can only go upward, which is the
        // direction there is room in and the direction the board grows anyway.
        // The keys stay where they are whatever the height is doing.
        .frame(maxHeight: .infinity, alignment: .bottom)
        // Clear, so the keyboard material from `loadView` is what shows through.
        // Keys stay opaque — they have to read as objects on a surface, not as
        // holes in it.
        .background(Color.clear)
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

/// The accessory bar reports its own height, which is the one measurement the
/// board cannot work out for itself.
private struct BarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
