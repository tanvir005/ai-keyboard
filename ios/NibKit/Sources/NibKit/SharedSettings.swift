import Foundation
import Observation

/// Settings and lightweight state shared between the host app and the keyboard
/// extension via the App Group.
///
/// Keep this small. It is `UserDefaults` — fine for flags, a quota counter and
/// a handful of tone presets, wrong for edit history (see `EditHistoryLog`).
@Observable
public final class SharedSettings {
    public static let shared = SharedSettings()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.soundEnabled: true,
            Key.predictionEnabled: true,
            // Off by default. This is the privacy promise from the Settings
            // screen, and TextContextResolver reads it literally.
            Key.readFullDraft: false,
            // On, like every keyboard people arrive from. It also has to be on
            // by default to survive a build with no App Group: the extension
            // then reads its own `UserDefaults.standard`, never sees what the
            // host app wrote, and lives on these registered values forever.
            // A dead-feeling keyboard is the worse failure mode.
            Key.hapticsEnabled: true,
        ])
    }

    /// Where the keyboard keeps what it has learned about how this person
    /// writes. Named here rather than in the extension so the host app's
    /// "Clear learned words" can reach the same box the keyboard writes to.
    public static let learnedWordsKey = "next_word_model"

    /// Throws away the learned next-word table.
    ///
    /// The keyboard reloads it when it next launches, so a keyboard on screen
    /// at the moment this is tapped keeps its copy until it is dismissed.
    public func forgetLearnedWords() {
        defaults.removeObject(forKey: Self.learnedWordsKey)
    }

    private enum Key {
        static let soundEnabled = "sound_enabled"
        static let hapticsEnabled = "haptics_enabled"
        static let predictionEnabled = "prediction_enabled"
        static let readFullDraft = "read_full_draft"
        static let onboardingComplete = "onboarding_complete"
        static let tonePresets = "tone_presets"
        static let quotaUsed = "quota_used"
        static let quotaDay = "quota_day"
        static let streakDays = "streak_days"
        static let hasFullAccess = "last_known_has_full_access"
        static let fullAccessCheckedAt = "full_access_checked_at"
        static let isPro = "is_pro"
    }

    // MARK: - Keyboard behaviour

    public var soundEnabled: Bool {
        get { defaults.bool(forKey: Key.soundEnabled) }
        set { defaults.set(newValue, forKey: Key.soundEnabled) }
    }

    public var hapticsEnabled: Bool {
        get { defaults.bool(forKey: Key.hapticsEnabled) }
        set { defaults.set(newValue, forKey: Key.hapticsEnabled) }
    }

    public var predictionEnabled: Bool {
        get { defaults.bool(forKey: Key.predictionEnabled) }
        set { defaults.set(newValue, forKey: Key.predictionEnabled) }
    }

    /// Governs how much text the extension may read. See `TextContextResolver`.
    public var readFullDraft: Bool {
        get { defaults.bool(forKey: Key.readFullDraft) }
        set { defaults.set(newValue, forKey: Key.readFullDraft) }
    }

    public var onboardingComplete: Bool {
        get { defaults.bool(forKey: Key.onboardingComplete) }
        set { defaults.set(newValue, forKey: Key.onboardingComplete) }
    }

    // MARK: - Entitlement (stubbed until the backend exists)

    public var isPro: Bool {
        get { defaults.bool(forKey: Key.isPro) }
        set { defaults.set(newValue, forKey: Key.isPro) }
    }

    // MARK: - Full Access
    //
    // The host app cannot query `hasFullAccess` — it is an extension-only
    // property. The extension records what it saw; the host app reports it with
    // an honest "as of last time you used the keyboard" caveat.

    public var lastKnownHasFullAccess: Bool {
        get { defaults.bool(forKey: Key.hasFullAccess) }
        set { defaults.set(newValue, forKey: Key.hasFullAccess) }
    }

    public var fullAccessCheckedAt: Date? {
        get { defaults.object(forKey: Key.fullAccessCheckedAt) as? Date }
        set { defaults.set(newValue, forKey: Key.fullAccessCheckedAt) }
    }

    public func recordFullAccess(_ granted: Bool) {
        lastKnownHasFullAccess = granted
        fullAccessCheckedAt = Date()
    }

    // MARK: - Tone presets

    public var tonePresets: [TonePreset] {
        get {
            guard let data = defaults.data(forKey: Key.tonePresets),
                  let decoded = try? JSONDecoder().decode([TonePreset].self, from: data),
                  !decoded.isEmpty
            else { return TonePreset.builtIns }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.tonePresets)
        }
    }

    public func addPreset(_ preset: TonePreset) {
        tonePresets = tonePresets + [preset]
    }

    public func deletePreset(id: UUID) {
        tonePresets = tonePresets.filter { $0.id != id || $0.isBuiltIn }
    }

    // MARK: - Quota
    //
    // Client-side only, and deliberately so: this drives the "9 of 15 today"
    // chip and nothing more. Real enforcement belongs on the server, where a
    // forged client cannot reach it. Until the backend exists this is the only
    // counter there is — treat it as display state, not a security boundary.

    public static let freeDailyLimit = 15

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: Date())
    }

    public var quotaUsed: Int {
        if defaults.string(forKey: Key.quotaDay) != today { return 0 }
        return defaults.integer(forKey: Key.quotaUsed)
    }

    public var quotaLimit: Int? { isPro ? nil : Self.freeDailyLimit }

    public var quotaRemaining: Int? {
        guard let limit = quotaLimit else { return nil }
        return max(0, limit - quotaUsed)
    }

    public var isQuotaExhausted: Bool {
        guard let remaining = quotaRemaining else { return false }
        return remaining <= 0
    }

    @discardableResult
    public func consumeQuota() -> Bool {
        guard !isQuotaExhausted else { return false }
        let used = quotaUsed
        defaults.set(today, forKey: Key.quotaDay)
        defaults.set(used + 1, forKey: Key.quotaUsed)
        return true
    }

    public var streakDays: Int {
        get { max(1, defaults.integer(forKey: Key.streakDays)) }
        set { defaults.set(newValue, forKey: Key.streakDays) }
    }
}
