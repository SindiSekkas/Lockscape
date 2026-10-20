import AppKit
import os

/// What `WallpaperSwapper` needs from the system, so tests can substitute a fake.
protocol WallpaperSystem {
    /// `desktopImageURL` of every screen, in screen order.
    var imagePaths: [String] { get }
    /// Sets the desktop picture of one screen, or of every screen when `screen` is nil.
    func setImage(_ path: String, screen: Int?)
    /// WallpaperAgent's store file.
    var store: Data { get }
    /// Replaces the store file and relaunches WallpaperAgent so the change takes effect.
    func replaceStore(_ store: Data)
}

/// The real thing: `NSWorkspace` for pictures, WallpaperAgent's store file and process for the rest.
struct SystemWallpaper: WallpaperSystem {
    private let workspace = NSWorkspace.shared
    private let storeURL = URL(fileURLWithPath: Settings.wallpaperStorePath)
    private let log = Logger(subsystem: Settings.bundleID, category: "system")

    var imagePaths: [String] {
        NSScreen.screens.map { workspace.desktopImageURL(for: $0)?.path ?? "" }
    }

    func setImage(_ path: String, screen index: Int?) {
        let screens = NSScreen.screens
        let targets = index.map { screens.indices.contains($0) ? [screens[$0]] : [] } ?? screens
        for screen in targets {
            do {
                try workspace.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [:])
            } catch {
                log.error("setDesktopImageURL failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    var store: Data {
        (try? Data(contentsOf: storeURL)) ?? Data()
    }

    /// WallpaperAgent rewrites its store a few hundred milliseconds after every change and re-reads it
    /// only at launch. So: freeze the agent so it cannot write any more, write the file, kill the agent
    /// and let launchd's KeepAlive bring it back.
    func replaceStore(_ store: Data) {
        let pid = agentPID()
        if let pid { kill(pid, SIGSTOP) }
        try? store.write(to: storeURL, options: .atomic)
        if let pid {
            kill(pid, SIGKILL)
            waitForRelaunch(after: pid)
        }
        _ = imagePaths // XPC round trip: launches the agent on demand if launchd has not done so yet
    }

    private func agentPID() -> pid_t? {
        pid_t(shell("/usr/bin/pgrep", "-x", "WallpaperAgent"))
    }

    private func waitForRelaunch(after oldPID: pid_t) {
        for _ in 0..<100 {
            if let pid = agentPID(), pid != oldPID { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
}

/// Runs a command-line tool and returns its trimmed standard output.
private func shell(_ tool: String, _ arguments: String...) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return "" }
    process.waitUntilExit()
    return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
