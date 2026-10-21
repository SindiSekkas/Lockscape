import CoreGraphics
import Foundation

/// Forwards loginwindow's lock and unlock notifications.
final class LockWatcher: NSObject {
    private let onLock: () -> Void
    private let onUnlock: () -> Void

    init(onLock: @escaping () -> Void, onUnlock: @escaping () -> Void) {
        self.onLock = onLock
        self.onUnlock = onUnlock
        super.init()

        // `.deliverImmediately`: otherwise a background app receives these only once it becomes active.
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(screenLocked), name: Settings.lockNotification,
                           object: nil, suspensionBehavior: .deliverImmediately)
        center.addObserver(self, selector: #selector(screenUnlocked), name: Settings.unlockNotification,
                           object: nil, suspensionBehavior: .deliverImmediately)
    }

    /// True while the lock screen is up, e.g. when the app is relaunched during a lock.
    static var isScreenLocked: Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return session?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    @objc private func screenLocked() { onLock() }
    @objc private func screenUnlocked() { onUnlock() }
}
