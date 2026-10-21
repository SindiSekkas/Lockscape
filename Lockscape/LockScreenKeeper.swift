import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import os

/// How long the display stays on after the screen locks.
enum KeepScreenOn: Int, CaseIterable {
    case off = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case untilUnlocked = -1

    var title: String {
        switch self {
        case .off: "Off"
        case .oneHour: "1 Hour"
        case .untilUnlocked: "Until Unlocked"
        default: "\(rawValue) Minutes"
        }
    }

    /// nil means no limit.
    var duration: TimeInterval? {
        self == .untilUnlocked ? nil : TimeInterval(rawValue * 60)
    }
}

struct PowerState: Equatable {
    var onBattery: Bool
    var batteryPercent: Int? // nil on Macs without a battery

    static var current: PowerState {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let providing = IOPSGetProvidingPowerSourceType(info).takeUnretainedValue() as String
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        let battery = sources
            .compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
            .first { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType }
        let percent = battery.flatMap { battery -> Int? in
            guard let current = battery[kIOPSCurrentCapacityKey] as? Int,
                  let max = battery[kIOPSMaxCapacityKey] as? Int, max > 0 else { return nil }
            return current * 100 / max
        }
        return PowerState(onBattery: providing == kIOPMBatteryPowerKey, batteryPercent: percent)
    }
}

/// Keeps the display on while the screen is locked.
///
/// loginwindow turns the display off 30 seconds after the lock screen appears, whatever the
/// "Turn display off" setting says, unless a process holds a PreventUserIdleDisplaySleep
/// assertion (checked on macOS 27.0.1). That assertion only stops idle dimming: closing the lid
/// or putting the Mac to sleep works as usual.
final class LockScreenKeeper {
    static let minimumBatteryPercent = 20

    private let log = Logger(subsystem: Settings.bundleID, category: "keeper")
    private var isLocked = false
    private var deadline: Date?
    private var assertion: IOPMAssertionID?
    private var expiryTimer: Timer?
    private var powerSource: CFRunLoopSource?

    /// Whether the display may be held on, given the time left (nil for no limit) and the power source.
    static func shouldHold(remaining: TimeInterval?, power: PowerState, allowBattery: Bool) -> Bool {
        if let remaining, remaining <= 0 { return false }
        if let percent = power.batteryPercent, percent < minimumBatteryPercent { return false }
        return !power.onBattery || allowBattery
    }

    func screenLocked() {
        let mode = Settings.keepScreenOn
        guard mode != .off else { return }
        isLocked = true
        deadline = mode.duration.map { Date().addingTimeInterval($0) }
        expiryTimer?.invalidate()
        if let duration = mode.duration {
            expiryTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in self?.update() }
        }
        watchPower()
        update()
    }

    func screenUnlocked() {
        isLocked = false
        deadline = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
        stopWatchingPower()
        update()
    }

    /// Takes or releases the assertion to match the lock state, the time left and the power source.
    private func update() {
        let remaining = deadline?.timeIntervalSinceNow
        let hold = isLocked && Self.shouldHold(remaining: remaining, power: .current,
                                               allowBattery: Settings.keepScreenOnBattery)
        if hold, assertion == nil {
            take(timeout: remaining)
        } else if !hold, let id = assertion {
            IOPMAssertionRelease(id)
            assertion = nil
            log.info("lock screen display assertion released")
        }
    }

    /// The timeout lets powerd drop the assertion on its own if the app hangs.
    private func take(timeout: TimeInterval?) {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithDescription(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            "Lockscape keeps the lock screen on" as CFString,
            nil, nil, nil,
            timeout ?? 0,
            kIOPMAssertionTimeoutActionRelease as CFString,
            &id)
        if result == kIOReturnSuccess {
            assertion = id
            log.info("lock screen display assertion taken")
        } else {
            log.error("IOPMAssertionCreateWithDescription failed: \(result)")
        }
    }

    /// Unplugging the adapter or a draining battery releases the assertion; plugging back in takes it again.
    private func watchPower() {
        guard powerSource == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<LockScreenKeeper>.fromOpaque(context).takeUnretainedValue().update()
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        powerSource = source
    }

    private func stopWatchingPower() {
        guard let source = powerSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        powerSource = nil
    }
}
