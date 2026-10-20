import AppKit

// Lockscape — a separate wallpaper for the macOS lock screen.
//
// Since Sonoma the lock screen renders the live desktop wallpaper and macOS offers no
// setting for a different image. Lockscape listens for loginwindow's lock notification,
// swaps the desktop wallpaper to your picture before the lock screen is drawn, and swaps
// the original back on unlock.

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "--restore":
    // uninstall.sh: put the desktop back if the app died while the screen was locked.
    WallpaperSwapper().restoreIfNeeded()
    exit(0)
case "--register":
    // install.sh: enable the login item without waiting for the first launch.
    Settings.loginItemOffered = true
    try? LoginItem.setEnabled(true)
    print("Login item: \(LoginItem.isEnabled ? "enabled" : "not enabled")")
    exit(0)
case "--unregister":
    // uninstall.sh: remove the login item before the app bundle is deleted.
    try? LoginItem.setEnabled(false)
    exit(0)
case "--post":
    // integration-test.sh: simulate lock and unlock without locking the screen.
    guard arguments.count == 2 else { exit(2) }
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name(arguments[1]), object: nil, userInfo: nil, deliverImmediately: true)
    exit(0)
default:
    break // no flag, or arguments from Xcode, XCTest or LaunchServices: run the app
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

if Settings.isUnitTestHost {
    app.run() // XCTest drives the process; the app stays out of the way
}

// A login-item launch and a double-click in Finder must not produce two instances.
if !Settings.isIntegrationTest,
   NSRunningApplication.runningApplications(withBundleIdentifier: Settings.bundleID).count > 1 {
    exit(0)
}

let swapper = WallpaperSwapper()
let statusMenu = StatusMenu(swapper: swapper)
let lockWatcher = LockWatcher(onLock: swapper.lock, onUnlock: swapper.unlock)

swapper.restoreIfNeeded() // crashed or shut down while locked?
LoginItem.enableOnFirstLaunch()
app.run()
