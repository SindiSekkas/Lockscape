import AppKit
import UniformTypeIdentifiers

/// The menu bar item: pick the pictures, pause, login item, quit.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let swapper: WallpaperSwapper

    init(swapper: WallpaperSwapper) {
        self.swapper = swapper
        super.init()
        item.button?.image = NSImage(systemSymbolName: "lock.display", accessibilityDescription: "Lockscape")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    /// Rebuilt on every click so it always reflects the current settings.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let lockImageName = Settings.imagePath.map { ($0 as NSString).lastPathComponent } ?? "none"
        menu.addItem(withTitle: "Lock screen: \(lockImageName)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Choose Lock Screen Image…", action: #selector(chooseLockImage), keyEquivalent: "").target = self
        menu.addItem(.separator())

        menu.addItem(withTitle: "Desktop: \(swapper.desktopImageName ?? "system wallpaper")", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Choose Desktop Image…", action: #selector(chooseDesktopImage), keyEquivalent: "").target = self
        menu.addItem(.separator())

        let keepOn = menu.addItem(withTitle: "Keep Lock Screen On", action: nil, keyEquivalent: "")
        keepOn.submenu = keepScreenOnMenu()
        menu.addItem(.separator())

        let enabled = menu.addItem(withTitle: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        enabled.state = Settings.isEnabled ? .on : .off

        let loginItem = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItem.isEnabled ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Lockscape", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func keepScreenOnMenu() -> NSMenu {
        let menu = NSMenu()
        for option in KeepScreenOn.allCases {
            let item = menu.addItem(withTitle: option.title, action: #selector(chooseKeepScreenOn(_:)), keyEquivalent: "")
            item.target = self
            item.tag = option.rawValue
            item.state = Settings.keepScreenOn == option ? .on : .off
        }
        menu.addItem(.separator())
        let battery = menu.addItem(withTitle: "Also on Battery", action: #selector(toggleKeepOnBattery), keyEquivalent: "")
        battery.target = self
        battery.state = Settings.keepScreenOnBattery ? .on : .off
        return menu
    }

    @objc private func chooseKeepScreenOn(_ item: NSMenuItem) {
        Settings.keepScreenOn = KeepScreenOn(rawValue: item.tag) ?? .off
    }

    @objc private func toggleKeepOnBattery() {
        Settings.keepScreenOnBattery.toggle()
    }

    @objc private func chooseLockImage() {
        if let url = pickImage() { Settings.imagePath = url.path }
    }

    @objc private func chooseDesktopImage() {
        if let url = pickImage() { swapper.setDesktop(url) }
    }

    @objc private func toggleEnabled() {
        Settings.isEnabled.toggle()
        if !Settings.isEnabled { swapper.restoreIfNeeded() }
    }

    @objc private func toggleLoginItem() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func pickImage() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }
}
