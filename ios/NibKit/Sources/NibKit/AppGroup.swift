import Foundation

/// Single source of truth for cross-target identifiers.
///
/// These strings must match, character for character, the values in
/// `Nib.entitlements` and `NibKeyboard.entitlements`. Change them in one
/// place only — here — and update both entitlements files to match.
public enum AppGroup {
    public static let identifier = "group.com.nib.app"
    public static let keychainAccessGroup = "group.com.nib.app"

    /// Shared defaults for settings, quota, tone presets and the
    /// last-known Full Access flag.
    ///
    /// Falls back to `.standard` when the App Group is unavailable — which
    /// happens on an unsigned build, or before the group is registered in the
    /// developer portal. The app still runs in that case; it just loses
    /// host-app ↔ extension state sharing. See ios/README.md.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// True when the real shared container is actually reachable. The host app
    /// uses this to warn during development rather than fail silently.
    public static var isSharedContainerAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }

    /// Directory inside the shared container, used for the edit-history log.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
