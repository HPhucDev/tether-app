import Foundation
import TetherCore

enum BluetoothOffAction: String, CaseIterable, Identifiable {
    case notifyOnly
    case lock
    var id: String { rawValue }
    var title: String { self == .notifyOnly ? "Chỉ thông báo" : "Khoá luôn" }
}

/// User settings persisted in UserDefaults.
@MainActor
final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults

    @Published var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Keys.enabled) } }
    @Published var phoneID: UUID? { didSet { defaults.set(phoneID?.uuidString, forKey: Keys.phoneID) } }
    @Published var phoneName: String? { didSet { defaults.set(phoneName, forKey: Keys.phoneName) } }
    @Published var watchID: UUID? { didSet { defaults.set(watchID?.uuidString, forKey: Keys.watchID) } }
    @Published var watchName: String? { didSet { defaults.set(watchName, forKey: Keys.watchName) } }
    @Published var otherID: UUID? { didSet { defaults.set(otherID?.uuidString, forKey: Keys.otherID) } }
    @Published var otherName: String? { didSet { defaults.set(otherName, forKey: Keys.otherName) } }
    @Published var lockPolicy: LockPolicy { didSet { defaults.set(lockPolicy.rawValue, forKey: Keys.policy) } }
    @Published var farThreshold: Double { didSet { defaults.set(farThreshold, forKey: Keys.far) } }
    @Published var nearThreshold: Double { didSet { defaults.set(nearThreshold, forKey: Keys.near) } }
    @Published var lockDelay: Double { didSet { defaults.set(lockDelay, forKey: Keys.delay) } }
    @Published var bluetoothOffAction: BluetoothOffAction { didSet { defaults.set(bluetoothOffAction.rawValue, forKey: Keys.btOff) } }
    @Published var notifyOnLock: Bool { didSet { defaults.set(notifyOnLock, forKey: Keys.notify) } }
    @Published var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarded) } }
    @Published var dockIconMode: DockIconMode { didSet { defaults.set(dockIconMode.rawValue, forKey: Keys.dock) } }

    // Automation
    @Published var scheduleEnabled: Bool { didSet { defaults.set(scheduleEnabled, forKey: Keys.scheduleOn) } }
    @Published var schedule: ActiveSchedule { didSet { defaults.set(try? JSONEncoder().encode(schedule), forKey: Keys.schedule) } }
    @Published var wakeOnReturn: Bool { didSet { defaults.set(wakeOnReturn, forKey: Keys.wake) } }
    @Published var leaveShortcut: String { didSet { defaults.set(leaveShortcut, forKey: Keys.leaveShortcut) } }
    @Published var returnShortcut: String { didSet { defaults.set(returnShortcut, forKey: Keys.returnShortcut) } }

    // Desk time
    @Published var breakReminder: Bool { didSet { defaults.set(breakReminder, forKey: Keys.breakOn) } }
    @Published var breakMinutes: Int { didSet { defaults.set(breakMinutes, forKey: Keys.breakMinutes) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let d = ProximityConfiguration.default
        defaults.register(defaults: [
            Keys.enabled: true,
            Keys.policy: LockPolicy.allAway.rawValue,
            Keys.far: d.farThreshold,
            Keys.near: d.nearThreshold,
            Keys.delay: d.lockDelay,
            Keys.btOff: BluetoothOffAction.notifyOnly.rawValue,
            Keys.notify: true,
            Keys.onboarded: false,
            Keys.scheduleOn: false,
            Keys.wake: false,
            Keys.breakOn: false,
            Keys.breakMinutes: 45,
        ])
        Self.migrateSingleDevice(defaults)
        isEnabled = defaults.bool(forKey: Keys.enabled)
        phoneID = defaults.string(forKey: Keys.phoneID).flatMap(UUID.init(uuidString:))
        phoneName = defaults.string(forKey: Keys.phoneName)
        watchID = defaults.string(forKey: Keys.watchID).flatMap(UUID.init(uuidString:))
        watchName = defaults.string(forKey: Keys.watchName)
        otherID = defaults.string(forKey: Keys.otherID).flatMap(UUID.init(uuidString:))
        otherName = defaults.string(forKey: Keys.otherName)
        lockPolicy = LockPolicy(rawValue: defaults.string(forKey: Keys.policy) ?? "") ?? .allAway
        farThreshold = defaults.double(forKey: Keys.far)
        nearThreshold = defaults.double(forKey: Keys.near)
        lockDelay = defaults.double(forKey: Keys.delay)
        bluetoothOffAction = BluetoothOffAction(rawValue: defaults.string(forKey: Keys.btOff) ?? "") ?? .notifyOnly
        notifyOnLock = defaults.bool(forKey: Keys.notify)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)
        dockIconMode = DockIconMode(rawValue: defaults.string(forKey: Keys.dock) ?? "") ?? .whileWindowOpen
        scheduleEnabled = defaults.bool(forKey: Keys.scheduleOn)
        schedule = defaults.data(forKey: Keys.schedule).flatMap { try? JSONDecoder().decode(ActiveSchedule.self, from: $0) } ?? .workHours
        wakeOnReturn = defaults.bool(forKey: Keys.wake)
        leaveShortcut = defaults.string(forKey: Keys.leaveShortcut) ?? ""
        returnShortcut = defaults.string(forKey: Keys.returnShortcut) ?? ""
        breakReminder = defaults.bool(forKey: Keys.breakOn)
        breakMinutes = defaults.integer(forKey: Keys.breakMinutes)
    }

    /// Protection is on and, if a schedule is set, we're inside it.
    func isWithinSchedule(at date: Date = Date()) -> Bool {
        !scheduleEnabled || schedule.isActive(at: date)
    }

    /// Lock-distance presets: far threshold in dBm (≈ 2 m, ≈ 4 m, ≈ 8 m).
    enum DistancePreset: Int, CaseIterable, Identifiable {
        case near = -67, medium = -75, far = -82
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .near: return "Gần"
            case .medium: return "Vừa"
            case .far: return "Xa"
            }
        }
        var detail: String { DistanceEstimate.text(rssi: Double(rawValue)) }
    }

    var distancePreset: DistancePreset? {
        DistancePreset(rawValue: Int(farThreshold.rounded()))
    }

    func apply(_ preset: DistancePreset) {
        farThreshold = Double(preset.rawValue)
        nearThreshold = farThreshold + 10
    }

    /// Forgets every device and preference. Onboarding stays marked as done:
    /// resetting settings must not force the tutorial again.
    func resetToDefaults() {
        Keys.all.filter { $0 != Keys.onboarded }.forEach(defaults.removeObject(forKey:))
        let d = ProximityConfiguration.default
        isEnabled = true
        phoneID = nil
        phoneName = nil
        watchID = nil
        watchName = nil
        otherID = nil
        otherName = nil
        lockPolicy = .allAway
        farThreshold = d.farThreshold
        nearThreshold = d.nearThreshold
        lockDelay = d.lockDelay
        bluetoothOffAction = .notifyOnly
        notifyOnLock = true
        dockIconMode = .whileWindowOpen
        scheduleEnabled = false
        schedule = .workHours
        wakeOnReturn = false
        leaveShortcut = ""
        returnShortcut = ""
        breakReminder = false
        breakMinutes = 45
    }

    var proximityConfiguration: ProximityConfiguration {
        var c = ProximityConfiguration.default
        c.farThreshold = farThreshold
        c.nearThreshold = nearThreshold
        c.lockDelay = lockDelay
        // Passive listening: a locked iPhone / idle Watch advertises less often, so allow longer gaps.
        c.signalTimeout = 10
        return c
    }

    func target(_ kind: DeviceKind) -> DeviceTarget? {
        deviceID(kind).map { DeviceTarget(id: $0, name: deviceName(kind)) }
    }

    func deviceID(_ kind: DeviceKind) -> UUID? {
        switch kind {
        case .iPhone: return phoneID
        case .watch: return watchID
        case .other: return otherID
        }
    }

    func deviceName(_ kind: DeviceKind) -> String? {
        switch kind {
        case .iPhone: return phoneName
        case .watch: return watchName
        case .other: return otherName
        }
    }

    var trackedKinds: [DeviceKind] { DeviceKind.allCases.filter { deviceID($0) != nil } }
    var hasAnyDevice: Bool { !trackedKinds.isEmpty }
    var hasMultipleDevices: Bool { trackedKinds.count > 1 }

    func setDevice(_ kind: DeviceKind, id: UUID?, name: String?) {
        setDeviceID(kind, id)
        switch kind {
        case .iPhone: phoneName = name
        case .watch: watchName = name
        case .other: otherName = name
        }
    }

    /// Updates only the identifier (device re-identified after its Bluetooth address rotated).
    func setDeviceID(_ kind: DeviceKind, _ id: UUID?) {
        switch kind {
        case .iPhone: phoneID = id
        case .watch: watchID = id
        case .other: otherID = id
        }
    }

    /// v0.1 stored one device + a mode; move it into the per-kind keys.
    private static func migrateSingleDevice(_ d: UserDefaults) {
        guard let old = d.string(forKey: "deviceID") else { return }
        let name = d.string(forKey: "deviceName")
        if d.string(forKey: "mode") == "watch" {
            d.set(old, forKey: Keys.watchID)
            d.set(name, forKey: Keys.watchName)
        } else {
            d.set(old, forKey: Keys.phoneID)
            d.set(name, forKey: Keys.phoneName)
        }
        ["deviceID", "deviceName", "mode", "beaconID"].forEach(d.removeObject(forKey:))
    }

    private enum Keys {
        static let enabled = "enabled"
        static let phoneID = "phoneID"
        static let phoneName = "phoneName"
        static let watchID = "watchID"
        static let watchName = "watchName"
        static let otherID = "otherID"
        static let otherName = "otherName"
        static let policy = "lockPolicy"
        static let far = "farThreshold"
        static let near = "nearThreshold"
        static let delay = "lockDelay"
        static let btOff = "bluetoothOffAction"
        static let notify = "notifyOnLock"
        static let onboarded = "hasCompletedOnboarding"
        static let dock = "dockIconMode"
        static let scheduleOn = "scheduleEnabled"
        static let schedule = "schedule"
        static let wake = "wakeOnReturn"
        static let leaveShortcut = "leaveShortcut"
        static let returnShortcut = "returnShortcut"
        static let breakOn = "breakReminder"
        static let breakMinutes = "breakMinutes"

        static let all = [
            enabled, phoneID, phoneName, watchID, watchName, otherID, otherName,
            policy, far, near, delay, btOff, notify, onboarded, dock,
            scheduleOn, schedule, wake, leaveShortcut, returnShortcut, breakOn, breakMinutes,
        ]
    }
}
