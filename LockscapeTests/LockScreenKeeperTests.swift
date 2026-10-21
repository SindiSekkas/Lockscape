import XCTest
@testable import Lockscape

final class LockScreenKeeperTests: XCTestCase {
    private let adapter = PowerState(onBattery: false, batteryPercent: 80)
    private let battery = PowerState(onBattery: true, batteryPercent: 80)

    func testHoldsOnThePowerAdapter() {
        XCTAssertTrue(LockScreenKeeper.shouldHold(remaining: 300, power: adapter, allowBattery: false))
    }

    func testHoldsOnBatteryOnlyWhenAllowed() {
        XCTAssertFalse(LockScreenKeeper.shouldHold(remaining: 300, power: battery, allowBattery: false))
        XCTAssertTrue(LockScreenKeeper.shouldHold(remaining: 300, power: battery, allowBattery: true))
    }

    func testReleasesBelowTwentyPercentEvenWhenPluggedIn() {
        let low = PowerState(onBattery: true, batteryPercent: 19)
        let charging = PowerState(onBattery: false, batteryPercent: 19)
        XCTAssertFalse(LockScreenKeeper.shouldHold(remaining: nil, power: low, allowBattery: true))
        XCTAssertFalse(LockScreenKeeper.shouldHold(remaining: nil, power: charging, allowBattery: true))
        XCTAssertTrue(LockScreenKeeper.shouldHold(remaining: nil, power: PowerState(onBattery: true, batteryPercent: 20), allowBattery: true))
    }

    func testHoldsOnMacsWithoutABattery() {
        XCTAssertTrue(LockScreenKeeper.shouldHold(remaining: nil, power: PowerState(onBattery: false, batteryPercent: nil), allowBattery: false))
    }

    func testReleasesWhenTheTimeIsUp() {
        XCTAssertFalse(LockScreenKeeper.shouldHold(remaining: 0, power: adapter, allowBattery: false))
        XCTAssertTrue(LockScreenKeeper.shouldHold(remaining: nil, power: adapter, allowBattery: false), "until unlocked")
    }

    func testDurations() {
        XCTAssertEqual(KeepScreenOn.fiveMinutes.duration, 300)
        XCTAssertEqual(KeepScreenOn.oneHour.duration, 3600)
        XCTAssertNil(KeepScreenOn.untilUnlocked.duration)
        XCTAssertEqual(KeepScreenOn.allCases.map(\.title),
                       ["Off", "5 Minutes", "15 Minutes", "30 Minutes", "1 Hour", "Until Unlocked"])
    }
}
