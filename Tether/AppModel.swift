import AppKit
import Combine
import Foundation
import os
import TetherCore

/// Wires Bluetooth, the proximity engine, the locker and system events together.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Surface: Hashable { case popover, settingsDevices, settingsDistance, onboarding }

    let settings = SettingsStore()
    let lockHistory = LockHistory()
    let deskTime = DeskTimeStore()
    let newFeatures = NewFeatureStore()

    /// Tether is switched on but the schedule says "not now".
    @Published private(set) var isOffSchedule = false

    @Published private(set) var status: ProximityStatus = .searching
    @Published private(set) var power: BluetoothPower = .unknown
    @Published private(set) var connections: [DeviceKind: ConnectionState] = [:]
    /// Strongest smoothed RSSI across devices; refreshed only while a UI surface is visible.
    @Published private(set) var currentRSSI: Double?
    /// Smoothed RSSI per device; refreshed only while a UI surface is visible.
    @Published private(set) var deviceRSSI: [DeviceKind: Double] = [:]
    @Published private(set) var devices: [DiscoveredDevice] = []
    @Published private(set) var historySamples: [DeviceKind: [RSSISample]] = [:]

    private let log = Logger(subsystem: "com.simple.tether", category: "engine")
    /// Created on first use (start), so merely touching AppModel never opens Bluetooth.
    private lazy var bluetooth = BluetoothService()
    private let locker = ScreenLocker()
    private let system = SystemObserver()
    private var engine = ProximityEngine()
    private var histories: [DeviceKind: RSSIHistory] = Dictionary(uniqueKeysWithValues: DeviceKind.allCases.map { ($0, RSSIHistory(window: 300, capacity: 256)) })
    private var timer: Timer?
    private var visibleSurfaces: Set<Surface> = []
    private var calibrationBuffer: [Double]?
    private var cancellables: Set<AnyCancellable> = []
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        applySettings()
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &cancellables)

        bluetooth.onPowerChange = { [weak self] in self?.handlePower($0) }
        bluetooth.onConnectionChange = { [weak self] kind, state in self?.connections[kind] = state }
        bluetooth.onRSSI = { [weak self] kind, rssi, date in self?.handleRSSI(rssi, from: kind, at: date) }
        bluetooth.onDevices = { [weak self] in self?.devices = $0 }
        bluetooth.onTargetMoved = { [weak self] kind, id in
            guard let self else { return }
            self.settings.setDeviceID(kind, id)
        }
        for kind in DeviceKind.allCases { bluetooth.setTarget(settings.target(kind), for: kind) }

        // Nothing to decide while the screen is locked or the Mac sleeps, so Bluetooth scanning stops entirely.
        system.onScreenLocked = { [weak self] in
            guard let self else { return }
            self.engine.screenDidLock()
            if self.engine.isWaitingForReturn && self.wantsReturnEvent {
                // Keep listening so we notice you coming back (wake the display / run a shortcut).
                self.log.info("Screen locked: still listening for your return")
            } else {
                self.bluetooth.setSuspended(true)
                self.log.info("Screen locked: scanning paused")
            }
        }
        system.onScreenUnlocked = { [weak self] in
            guard let self else { return }
            self.engine.screenDidUnlock(at: Date())
            self.bluetooth.setSuspended(false)
            self.log.info("Screen unlocked: scanning resumed")
            self.refreshStatus()
        }
        system.onWillSleep = { [weak self] in
            guard let self else { return }
            self.deskTime.save()
            self.engine.resetTracking()
            self.bluetooth.setSuspended(true)
            self.log.info("Will sleep: tracking reset, scanning paused")
        }
        system.onDidWake = { [weak self] in
            guard let self else { return }
            self.engine.resetTracking()
            self.clearHistory()
            self.bluetooth.setSuspended(SystemObserver.isScreenLockedNow)
            self.bluetooth.restart()
            self.log.info("Did wake: tracking reset")
        }
        system.start()
        if SystemObserver.isScreenLockedNow {
            engine.screenDidLock()
            bluetooth.setSuspended(true)
        }

        if settings.notifyOnLock || settings.breakReminder { Notifier.requestAuthorization() }

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: UI visibility (gates expensive updates)

    func setVisible(_ surface: Surface, _ visible: Bool) {
        guard started else { return }
        if visible { visibleSurfaces.insert(surface) } else { visibleSurfaces.remove(surface) }
        bluetooth.setDiscoveryActive(!visibleSurfaces.isDisjoint(with: [.settingsDevices, .onboarding]))
        if visible { refreshLiveData() }
    }

    private var wantsLiveRSSI: Bool { !visibleSurfaces.isEmpty }
    private var wantsChart: Bool { !visibleSurfaces.isDisjoint(with: [.settingsDistance, .onboarding]) }

    // MARK: Actions

    var pausedUntil: Date? { engine.isPaused(at: Date()) ? engine.pausedUntil : nil }

    func pause(for interval: TimeInterval) {
        engine.pause(until: Date().addingTimeInterval(interval))
        log.info("Paused for \(Int(interval))s")
        refreshStatus()
    }

    func resume() {
        engine.resume()
        refreshStatus()
    }

    func testLock() {
        lock(reason: .test)
    }

    /// "Lock now" from the Shortcuts app.
    func lockFromShortcut() {
        lock(reason: .shortcut)
    }

    func connection(_ kind: DeviceKind) -> ConnectionState { connections[kind] ?? .idle }

    func select(_ device: DiscoveredDevice, as kind: DeviceKind) {
        // The same peripheral can't be both devices.
        for other in DeviceKind.allCases where other != kind && settings.deviceID(other) == device.id {
            settings.setDevice(other, id: nil, name: nil)
            retarget(other)
        }
        settings.setDevice(kind, id: device.id, name: device.displayName)
        retarget(kind)
    }

    func forget(_ kind: DeviceKind) {
        settings.setDevice(kind, id: nil, name: nil)
        retarget(kind)
    }

    /// Settings back to defaults: forgets devices, thresholds and preferences, clears the lock history
    /// and turns off "open at login". Does not re-run onboarding.
    func resetToDefaults() {
        settings.resetToDefaults()
        lockHistory.clear()
        deskTime.clear()
        LoginItem.setEnabled(false)
        engine.resume()
        engine.resetTracking()
        for kind in DeviceKind.allCases { retarget(kind) }
        clearHistory()
        applySettings()
        log.notice("Reset to defaults")
    }

    /// Distance tab: current position becomes the "far" threshold.
    func calibrateFarHere() {
        guard let r = engine.smoothedRSSI else { return }
        settings.farThreshold = r.rounded()
        settings.nearThreshold = max(settings.nearThreshold, settings.farThreshold + 8)
    }

    /// Averages raw RSSI samples over `duration` seconds (onboarding calibration).
    func measureAverageRSSI(duration: TimeInterval) async -> Double? {
        calibrationBuffer = []
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        let values = calibrationBuffer ?? []
        calibrationBuffer = nil
        return Calibration.average(values)
    }

    // MARK: Internals

    private func retarget(_ kind: DeviceKind) {
        engine.removeDevice(kind.rawValue)
        histories[kind]?.removeAll()
        deviceRSSI[kind] = nil
        historySamples[kind] = nil
        currentRSSI = engine.smoothedRSSI
        bluetooth.setTarget(settings.target(kind), for: kind)
        refreshStatus()
    }

    private func clearHistory() {
        for k in histories.keys { histories[k]?.removeAll() }
        historySamples = [:]
    }

    /// Device used for onboarding calibration: the first one chosen (iPhone, then Watch, then other).
    var calibrationKind: DeviceKind { settings.trackedKinds.first ?? .iPhone }

    /// Something should happen when you come back, so it's worth listening while the screen is locked.
    private var wantsReturnEvent: Bool {
        settings.wakeOnReturn || !settings.returnShortcut.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func applySettings(at now: Date = Date()) {
        engine.configuration = settings.proximityConfiguration
        let inSchedule = settings.isWithinSchedule(at: now)
        engine.isEnabled = settings.isEnabled && inSchedule
        let offSchedule = settings.isEnabled && !inSchedule
        if offSchedule != isOffSchedule { isOffSchedule = offSchedule }
        engine.policy = settings.lockPolicy
        if WindowFocus.dockMode != settings.dockIconMode { WindowFocus.dockMode = settings.dockIconMode }
    }

    private func handleRSSI(_ rssi: Double, from kind: DeviceKind, at date: Date) {
        engine.ingest(rssi: rssi, at: date, device: kind.rawValue)
        histories[kind]?.append(RSSISample(date: date, rssi: rssi))
        if kind == calibrationKind { calibrationBuffer?.append(rssi) }
        log.debug("RSSI \(kind.rawValue, privacy: .public) \(rssi, format: .fixed(precision: 0)) smoothed \(self.engine.smoothedRSSI(for: kind.rawValue) ?? 0, format: .fixed(precision: 1))")
    }

    private func handlePower(_ newPower: BluetoothPower) {
        let previous = power
        power = newPower
        let available = newPower == .poweredOn
        if !available && previous == .poweredOn {
            let now = Date()
            let couldLock = engine.isArmed && engine.isEnabled && !engine.isPaused(at: now) && !engine.isScreenLocked
            engine.resetTracking()
            if settings.bluetoothOffAction == .lock && couldLock {
                lock(reason: .bluetoothOff)
            } else if settings.isEnabled {
                Notifier.post(title: "Tether tạm ngưng", body: "Bluetooth đã tắt nên Tether không thể theo dõi thiết bị.")
            }
        }
        engine.isBluetoothAvailable = available
        refreshStatus()
    }

    private func tick() {
        let now = Date()
        // The schedule can switch protection on or off as the clock moves.
        if settings.scheduleEnabled, (settings.isEnabled && !settings.isWithinSchedule(at: now)) != isOffSchedule {
            applySettings(at: now)
        }

        let lost = engine.isSignalLost(at: now)
        let wasWaitingForReturn = engine.isWaitingForReturn
        if engine.evaluate(at: now) == .lock {
            lock(reason: lost ? .signalLost : .walkedAway)
        }
        if wasWaitingForReturn && !engine.isWaitingForReturn { userDidReturn() }
        trackDeskTime(at: now)
        refreshStatus(at: now)
        if wantsLiveRSSI || wantsChart { refreshLiveData(at: now) }
    }

    private func refreshStatus(at now: Date = Date()) {
        let s = engine.status(at: now)
        if s != status {
            log.info("Status \(String(describing: self.status), privacy: .public) -> \(String(describing: s), privacy: .public)")
            status = s
        }
    }

    private func refreshLiveData(at now: Date = Date()) {
        if currentRSSI != engine.smoothedRSSI { currentRSSI = engine.smoothedRSSI }
        var perDevice: [DeviceKind: Double] = [:]
        for k in DeviceKind.allCases { perDevice[k] = engine.smoothedRSSI(for: k.rawValue) }
        if perDevice != deviceRSSI { deviceRSSI = perDevice }
        if wantsChart {
            var samples: [DeviceKind: [RSSISample]] = [:]
            for (k, h) in histories where settings.deviceID(k) != nil { samples[k] = h.samples(asOf: now) }
            historySamples = samples
        }
    }

    /// A device came back near after Tether locked the Mac.
    private func userDidReturn() {
        log.notice("You came back")
        let locked = SystemObserver.isScreenLockedNow
        if settings.wakeOnReturn && locked { DisplayWaker.wake() }
        ShortcutRunner.run(settings.returnShortcut)
        // Done listening: back to the battery-friendly state until the screen is unlocked.
        if locked { bluetooth.setSuspended(true) }
    }

    private func trackDeskTime(at now: Date) {
        let present = settings.hasAnyDevice && power == .poweredOn && !engine.isScreenLocked && !engine.isAway(at: now)
        let remind = deskTime.update(present: present, at: now, remindEvery: settings.breakReminder ? settings.breakMinutes : nil)
        if remind {
            Notifier.post(
                title: "Đứng dậy vận động chút nhé",
                body: "Bạn đã ngồi \(settings.breakMinutes) phút liền. Đi lại vài phút cho đỡ mỏi.")
        }
    }

    private func lock(reason: LockReason) {
        let now = Date()
        // Snapshot what each device looked like at the moment of locking (for the History tab).
        let readings = settings.trackedKinds.map { kind in
            LockEvent.Reading(
                kind: kind.rawValue,
                name: settings.deviceName(kind),
                rssi: engine.devices[kind.rawValue].flatMap { d in
                    d.isSignalLost(at: now, timeout: engine.configuration.signalTimeout) ? nil : d.smoothedRSSI
                })
        }
        locker.lock { [weak self] method in MainActor.assumeIsolated {
            guard let self else { return }
            self.log.notice("Locked (\(reason.rawValue, privacy: .public)) via \(method.rawValue, privacy: .public)")
            self.lockHistory.record(LockEvent(date: now, reason: reason, method: method.rawValue, readings: readings))
            let automatic = reason != .test && reason != .shortcut
            if self.settings.notifyOnLock && automatic {
                Notifier.post(title: "Tether đã khoá Mac", body: reason.title)
            }
            if automatic && method != .failed {
                ShortcutRunner.run(self.settings.leaveShortcut)
            }
        } }
    }
}
