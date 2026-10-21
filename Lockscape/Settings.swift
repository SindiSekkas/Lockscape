import Foundation

/// Preferences and the few paths the app touches.
/// The `LOCKSCAPE_*` environment overrides exist for `scripts/integration-test.sh`.
enum Settings {
    static let bundleID = "com.sindisekkas.lockscape"

    private static let defaults = UserDefaults.standard
    private static let environment = ProcessInfo.processInfo.environment
    private static let home = NSHomeDirectory()

    /// `scripts/integration-test.sh` runs a second instance that listens to test notifications.
    static var isIntegrationTest: Bool { environment["LOCKSCAPE_TEST"] != nil }

    /// The app is the host process of `LockscapeTests`.
    static var isUnitTestHost: Bool { environment["XCTestConfigurationFilePath"] != nil }

    static var imagePath: String? {
        get { environment["LOCKSCAPE_IMAGE"] ?? defaults.string(forKey: "image") }
        set { defaults.set(newValue, forKey: "image") }
    }

    static var isEnabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    static var keepScreenOn: KeepScreenOn {
        get { KeepScreenOn(rawValue: defaults.integer(forKey: "keepScreenOn")) ?? .off }
        set { defaults.set(newValue.rawValue, forKey: "keepScreenOn") }
    }

    /// Off by default: on battery the lock screen goes dark as usual.
    static var keepScreenOnBattery: Bool {
        get { defaults.bool(forKey: "keepScreenOnBattery") }
        set { defaults.set(newValue, forKey: "keepScreenOnBattery") }
    }

    /// Set once the first launch has offered the login item, so a user who turned it off stays in charge.
    static var loginItemOffered: Bool {
        get { defaults.bool(forKey: "loginItemOffered") }
        set { defaults.set(newValue, forKey: "loginItemOffered") }
    }

    /// Exists only while the lock image is on the desktop; holds what to put back.
    static var statePath: String {
        environment["LOCKSCAPE_STATE"] ?? home + "/Library/Application Support/Lockscape/state.plist"
    }

    /// WallpaperAgent's own store. Read on lock, written back only to restore an Apple dynamic wallpaper.
    static let wallpaperStorePath = home + "/Library/Application Support/com.apple.wallpaper/Store/Index.plist"

    static var lockNotification: Notification.Name {
        Notification.Name(isIntegrationTest ? bundleID + ".test.locked" : "com.apple.screenIsLocked")
    }

    static var unlockNotification: Notification.Name {
        Notification.Name(isIntegrationTest ? bundleID + ".test.unlocked" : "com.apple.screenIsUnlocked")
    }
}
