import XCTest
@testable import Lockscape

/// Stands in for NSWorkspace and WallpaperAgent.
final class FakeWallpaperSystem: WallpaperSystem {
    var imagePaths: [String]
    var store: Data
    var setCalls: [(path: String, screen: Int?)] = []
    var replacedStores: [Data] = []
    /// What the desktop shows after a store replacement; nil means the replacement does not take effect.
    var imagePathsAfterReplace: [String]?

    init(imagePaths: [String], store: Data = Data("store".utf8)) {
        self.imagePaths = imagePaths
        self.store = store
    }

    func setImage(_ path: String, screen: Int?) {
        setCalls.append((path, screen))
        if let screen { imagePaths[screen] = path } else { imagePaths = imagePaths.map { _ in path } }
    }

    func replaceStore(_ store: Data) {
        replacedStores.append(store)
        if let paths = imagePathsAfterReplace { imagePaths = paths }
    }
}

final class WallpaperSwapperTests: XCTestCase {
    private var directory: URL!
    private var lockImage: String!
    private var desktopImage: String!
    private var stateURL: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        lockImage = directory.appendingPathComponent("lock.png").path
        desktopImage = directory.appendingPathComponent("desktop.png").path
        for path in [lockImage, desktopImage] { try Data().write(to: URL(fileURLWithPath: path!)) }
        stateURL = directory.appendingPathComponent("state.plist")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func makeSwapper(_ system: FakeWallpaperSystem, enabled: Bool = true) -> WallpaperSwapper {
        WallpaperSwapper(system: system, stateURL: stateURL,
                         lockImagePath: { self.lockImage }, isEnabled: { enabled })
    }

    private var hasRecord: Bool { FileManager.default.fileExists(atPath: stateURL.path) }

    func testLockPutsTheLockImageOnEveryScreenAndRecordsTheDesktop() {
        let system = FakeWallpaperSystem(imagePaths: [desktopImage, desktopImage])
        let swapper = makeSwapper(system)

        swapper.lock()
        swapper.waitForPendingWork()

        XCTAssertEqual(system.imagePaths, [lockImage, lockImage])
        XCTAssertTrue(hasRecord)
    }

    func testSecondLockKeepsTheOriginalRecord() {
        let system = FakeWallpaperSystem(imagePaths: [desktopImage])
        let swapper = makeSwapper(system)

        swapper.lock()
        swapper.lock()
        swapper.unlock()
        swapper.waitForPendingWork()

        XCTAssertEqual(system.imagePaths, [desktopImage], "the lock image must not be recorded as the desktop")
        XCTAssertFalse(hasRecord)
    }

    func testUnlockRestoresPictureFilesThroughTheAPI() {
        let system = FakeWallpaperSystem(imagePaths: [desktopImage])
        let swapper = makeSwapper(system)

        swapper.lock()
        swapper.unlock()
        swapper.waitForPendingWork()

        XCTAssertEqual(system.imagePaths, [desktopImage])
        XCTAssertTrue(system.replacedStores.isEmpty, "no WallpaperAgent restart for a picture file")
        XCTAssertFalse(hasRecord)
    }

    func testUnlockRestoresAppleWallpapersThroughTheStore() {
        let placeholder = "/System/Library/CoreServices/DefaultDesktop.heic"
        let store = Data("dynamic wallpaper".utf8)
        let system = FakeWallpaperSystem(imagePaths: [placeholder], store: store)
        system.imagePathsAfterReplace = [placeholder]
        let swapper = makeSwapper(system)

        swapper.lock()
        swapper.unlock()
        swapper.waitForPendingWork()

        XCTAssertEqual(system.replacedStores, [store])
        XCTAssertEqual(system.imagePaths, [placeholder])
        XCTAssertFalse(hasRecord)
    }

    func testStoreRestoreRetriesAndKeepsTheRecordWhenItDoesNotTakeEffect() {
        let system = FakeWallpaperSystem(imagePaths: ["/System/Library/CoreServices/DefaultDesktop.heic"])
        let swapper = makeSwapper(system)

        swapper.lock()
        swapper.unlock()
        swapper.waitForPendingWork()

        XCTAssertEqual(system.replacedStores.count, 3)
        XCTAssertTrue(hasRecord, "the next unlock or launch must try again")
    }

    func testLaunchRepairsTheDesktopFromAStaleRecord() {
        let system = FakeWallpaperSystem(imagePaths: [desktopImage])
        let crashed = makeSwapper(system)
        crashed.lock()
        crashed.waitForPendingWork()
        system.setCalls.removeAll()

        makeSwapper(system).restoreIfNeeded() // a new process after a crash while locked

        XCTAssertEqual(system.imagePaths, [desktopImage])
        XCTAssertFalse(hasRecord)
    }

    func testLaunchWithoutARecordTouchesNothing() {
        let system = FakeWallpaperSystem(imagePaths: [desktopImage])

        makeSwapper(system).restoreIfNeeded()

        XCTAssertTrue(system.setCalls.isEmpty)
        XCTAssertTrue(system.replacedStores.isEmpty)
    }

    func testDisabledSwapperIgnoresLocks() {
        let system = FakeWallpaperSystem(imagePaths: [desktopImage])
        let swapper = makeSwapper(system, enabled: false)

        swapper.lock()
        swapper.waitForPendingWork()

        XCTAssertEqual(system.imagePaths, [desktopImage])
        XCTAssertFalse(hasRecord)
    }
}
