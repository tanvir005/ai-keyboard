import UIKit
import NibKit

/// Keeps the learned-word table alive between keyboard sessions, and decides
/// when it is safe to add to it.
///
/// The safety rules live here rather than in `NextWordModel` because they are
/// about the *field being typed into*, which the model cannot see. The model
/// refuses anything containing a digit; this refuses whole fields.
final class NextWordStore {

    private static let storageKey = SharedSettings.learnedWordsKey

    /// The table only grows, and this process runs under a tight memory
    /// ceiling. Rare contexts are also the least useful — a phrase typed once
    /// is not a habit.
    private static let maximumContexts = 2_000

    /// Writing a plist on every space would be a disk write per keystroke-ish.
    /// Batched instead, with a flush when the keyboard goes away.
    private static let writeEvery = 12

    private let defaults: UserDefaults
    private var model: NextWordModel
    private var unsavedLearnings = 0

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults

        if
            let data = defaults.data(forKey: Self.storageKey),
            let stored = try? JSONDecoder().decode(NextWordModel.self, from: data)
        {
            model = stored
        } else {
            // Day one. A blank strip reads as broken rather than as new.
            model = NextWordSeed.model
        }
    }

    // MARK: - Reading

    func predictions(after context: [String], limit: Int) -> [String] {
        guard SharedSettings.shared.predictionEnabled else { return [] }
        return model.predictions(after: context, limit: limit)
    }

    // MARK: - Writing

    /// Records a finished word, if the field it was typed into allows it.
    func learn(previous: [String], next: String, in proxy: UITextDocumentProxy) {
        guard SharedSettings.shared.predictionEnabled else { return }
        guard Self.mayLearn(from: proxy) else { return }

        model.learn(previous: previous, next: next)

        unsavedLearnings += 1
        if unsavedLearnings >= Self.writeEvery { save() }
    }

    /// Whether this field's contents may be remembered at all.
    ///
    /// A password typed into a secure field is the obvious case, but the
    /// keyboard-type checks matter just as much: emails, URLs and phone numbers
    /// are not prose, and offering somebody's address back in a group chat is
    /// the same failure as offering their password.
    private static func mayLearn(from proxy: UITextDocumentProxy) -> Bool {
        if proxy.isSecureTextEntry == true { return false }

        // Compared rather than pattern-matched: these traits come from an
        // Objective-C protocol whose members are optional, and `==` reads the
        // same whether Swift surfaces them as `UIKeyboardType` or `UIKeyboardType?`.
        let type = proxy.keyboardType
        let excluded: [UIKeyboardType] = [
            .emailAddress, .URL, .numberPad, .phonePad,
            .decimalPad, .namePhonePad, .asciiCapableNumberPad,
        ]
        return !excluded.contains { $0 == type }
    }

    /// Writes the table out, off the thread that draws the keyboard.
    ///
    /// This used to sort a table of up to two thousand entries, encode it to
    /// JSON and write it to disk, all on the main thread, every twelfth word —
    /// which is to say mid-sentence, several times a message. Not slow enough
    /// to look like lag and exactly slow enough to feel like a stutter.
    ///
    /// The copy is taken here, synchronously, so what gets written is the table
    /// as it was at this moment rather than whatever it becomes while the write
    /// is in flight.
    func save() {
        guard unsavedLearnings > 0 else { return }
        unsavedLearnings = 0

        // Only when it is actually over the cap. Sorting the whole table to
        // discover it is within its limit is the common case and pure waste.
        if model.contextCount > Self.maximumContexts {
            model.prune(to: Self.maximumContexts)
        }

        let snapshot = model
        let defaults = defaults

        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    /// Back to the seed rather than to nothing: an empty table would leave the
    /// strip blank between words, which reads as a broken keyboard rather than
    /// as a cleared one.
    func forgetEverything() {
        model = NextWordSeed.model
        unsavedLearnings = 1
        save()
    }
}
