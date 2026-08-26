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

        switch proxy.keyboardType {
        case .some(.emailAddress), .some(.URL), .some(.numberPad),
             .some(.phonePad), .some(.decimalPad), .some(.namePhonePad),
             .some(.asciiCapableNumberPad):
            return false
        default:
            return true
        }
    }

    func save() {
        guard unsavedLearnings > 0 else { return }
        unsavedLearnings = 0

        model.prune(to: Self.maximumContexts)
        guard let data = try? JSONEncoder().encode(model) else { return }
        defaults.set(data, forKey: Self.storageKey)
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
