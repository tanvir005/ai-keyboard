import Foundation

/// Single source of truth for cross-target identifiers.
///
/// These strings must match, character for character, the values in
/// `Nib.entitlements` and `NibKeyboard.entitlements`. Change them in one
/// place only — here — and update both entitlements files to match.
///
/// They did not match for a while, and the way that failed is worth knowing:
/// the entitlements moved to the team's own identifier while this file still
/// said `group.com.nib.app`. Asking for a group the app was never granted is
/// not an error — `UserDefaults(suiteName:)` simply returns nil and the
/// fallback below takes over. Everything keeps working, nothing is shared, and
/// no message anywhere says why. The warning in Settings exists because of it.
///
/// `aikeybord` is spelled that way in the developer portal. It is the
/// registered identifier, so it is the correct one, typo and all — renaming it
/// means a new group and losing whatever is stored under the old one.
public enum AppGroup {
    public static let identifier = "group.com.feinapps.aikeybord"
    public static let keychainAccessGroup = "group.com.feinapps.aikeybord"

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
