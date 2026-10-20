import Foundation
import os

/// Puts the lock image on the desktop while the screen is locked and restores the real desktop afterwards.
///
/// Restoring depends on what was there. Picture files go back through `NSWorkspace`. Apple's dynamic
/// wallpapers (Golden Gate, aerials, ...) only report a placeholder URL under `/System` and cannot be
/// selected again through the public API, so for those the wallpaper store is put back as a whole.
final class WallpaperSwapper {
    /// What was on the desktop before the swap. Its presence on disk means "the lock image is on the desktop".
    struct SavedDesktop: Codable, Equatable {
        var imagePaths: [String]   // `desktopImageURL` per screen
        var store: Data            // WallpaperAgent's Index.plist
        var savedAt: Date
    }

    private let system: WallpaperSystem
    private let stateURL: URL
    private let lockImagePath: () -> String?
    private let isEnabled: () -> Bool
    private let log = Logger(subsystem: Settings.bundleID, category: "wallpaper")
    private let queue = DispatchQueue(label: Settings.bundleID + ".wallpaper") // serializes lock/unlock bursts

    init(system: WallpaperSystem = SystemWallpaper(),
         stateURL: URL = URL(fileURLWithPath: Settings.statePath),
         lockImagePath: @escaping () -> String? = { Settings.imagePath },
         isEnabled: @escaping () -> Bool = { Settings.isEnabled }) {
        self.system = system
        self.stateURL = stateURL
        self.lockImagePath = lockImagePath
        self.isEnabled = isEnabled
    }

    func lock() { queue.async { self.swapIn() } }
    func unlock() { queue.async { self.restore() } }
    func restoreIfNeeded() { queue.sync { restore() } }

    /// Sets the desktop wallpaper right away, so both pictures can be chosen from one menu.
    func setDesktop(_ url: URL) { queue.async { self.system.setImage(url.path, screen: nil) } }

    /// File name of the current desktop picture, or nil for one of Apple's wallpapers.
    var desktopImageName: String? {
        guard let path = system.imagePaths.first, isUserFile(path) else { return nil }
        return (path as NSString).lastPathComponent
    }

    /// Blocks until queued lock/unlock work has finished. Used by tests.
    func waitForPendingWork() { queue.sync {} }

    // MARK: - Swapping

    private func swapIn() {
        guard isEnabled(), let imagePath = lockImagePath(),
              FileManager.default.fileExists(atPath: imagePath) else { return }

        // A second lock while already swapped must not record the lock image as the desktop.
        if savedDesktop == nil {
            save(SavedDesktop(imagePaths: system.imagePaths, store: system.store, savedAt: Date()))
        }
        system.setImage(imagePath, screen: nil)
        log.info("lock image set")
    }

    private func restore() {
        guard let saved = savedDesktop else { return }

        if !saved.imagePaths.isEmpty, saved.imagePaths.allSatisfy(isUserFile) {
            if saved.imagePaths.count == 1 {
                system.setImage(saved.imagePaths[0], screen: nil)
            } else {
                for (index, path) in saved.imagePaths.enumerated() { system.setImage(path, screen: index) }
            }
        } else if !saved.store.isEmpty, !restoreStore(saved.store) {
            log.error("wallpaper store restore failed, keeping the record for the next unlock or launch")
            return
        }
        try? FileManager.default.removeItem(at: stateURL)
        log.info("desktop restored")
    }

    private func restoreStore(_ store: Data) -> Bool {
        for attempt in 1...3 {
            system.replaceStore(store)
            if !system.imagePaths.contains(where: { $0 == lockImagePath() }) { return true }
            log.warning("wallpaper store restore attempt \(attempt) did not take effect")
        }
        return false
    }

    // MARK: - Helpers

    private func isUserFile(_ path: String) -> Bool {
        !path.hasPrefix("/System/") && FileManager.default.fileExists(atPath: path)
    }

    private var savedDesktop: SavedDesktop? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? PropertyListDecoder().decode(SavedDesktop.self, from: data)
    }

    private func save(_ saved: SavedDesktop) {
        try? FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? PropertyListEncoder().encode(saved).write(to: stateURL, options: .atomic)
    }
}
