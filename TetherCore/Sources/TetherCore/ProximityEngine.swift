import Foundation

public struct ProximityConfiguration: Equatable, Sendable {
    /// Smoothed RSSI below this value counts as "far" (dBm).
    public var farThreshold: Double
    /// Smoothed RSSI must rise above this value to count as "near" again (dBm).
    public var nearThreshold: Double
    /// Seconds the device must stay away continuously before locking.
    public var lockDelay: TimeInterval
    /// No sample for longer than this counts as away.
    public var signalTimeout: TimeInterval
    /// EMA weight of the newest sample: s = (1 - a)·s + a·rssi.
    public var smoothingFactor: Double

    public init(
        farThreshold: Double = -75,
        nearThreshold: Double = -65,
        lockDelay: TimeInterval = 8,
        signalTimeout: TimeInterval = 6,
        smoothingFactor: Double = 0.3
    ) {
        self.farThreshold = farThreshold
        self.nearThreshold = nearThreshold
        self.lockDelay = lockDelay
        self.signalTimeout = signalTimeout
        self.smoothingFactor = smoothingFactor
    }

    public static let `default` = ProximityConfiguration()

    /// Keeps the near threshold strictly above the far threshold.
    public var sanitized: ProximityConfiguration {
        var c = self
        if c.nearThreshold <= c.farThreshold { c.nearThreshold = c.farThreshold + 1 }
        c.lockDelay = max(0, c.lockDelay)
        c.smoothingFactor = min(1, max(0.01, c.smoothingFactor))
        return c
    }
}

public enum ProximityStatus: Equatable, Sendable {
    case disabled
    case paused(until: Date)
    case bluetoothOff
    /// Not armed yet: waiting to see the device near once.
    case searching
    case near
    /// Weak signal, counting down to lock.
    case leaving(secondsLeft: Int)
    /// No signal, counting down to lock.
    case signalLost(secondsLeft: Int)
    /// Locked (or unlocked while away); waiting for the device to come back.
    case away
}

public enum ProximityDecision: Equatable, Sendable {
    case none
    case lock
}

/// When several devices are tracked, which condition counts as "you left".
public enum LockPolicy: String, CaseIterable, Sendable {
    /// Lock only when every tracked device is away (one device near = you're still here).
    case allAway
    /// Lock as soon as any device that was near goes away.
    case anyAway
}

/// Per-device signal tracking: smoothing, hysteresis zone, last sample time.
public struct DeviceSignal: Equatable, Sendable {
    public fileprivate(set) var smoothedRSSI: Double?
    public fileprivate(set) var lastSampleAt: Date?
    public fileprivate(set) var zone: ProximityEngine.Zone?
    /// Seen near since the last reset; only these take part in the `.anyAway` policy.
    public fileprivate(set) var hasBeenNear = false

    public func isSignalLost(at now: Date, timeout: TimeInterval) -> Bool {
        guard let last = lastSampleAt else { return true }
        return now.timeIntervalSince(last) > timeout
    }

    public func isPresent(at now: Date, timeout: TimeInterval) -> Bool {
        !isSignalLost(at: now, timeout: timeout) && zone == .near
    }
}

/// Pure state machine: feed it RSSI samples (per device) and the current time, ask whether to lock.
public struct ProximityEngine: Sendable {
    public enum Zone: Equatable, Sendable { case near, far }

    /// Device key used by the single-device convenience API.
    public static let defaultDevice = "default"

    public var configuration: ProximityConfiguration {
        didSet {
            configuration = configuration.sanitized
            for key in devices.keys { updateZone(key) }
        }
    }
    public var policy: LockPolicy = .allAway
    public var isEnabled = true
    public var isBluetoothAvailable = true

    public private(set) var devices: [String: DeviceSignal] = [:]
    public private(set) var isScreenLocked = false
    public private(set) var pausedUntil: Date?
    public private(set) var isArmed = false
    /// True after a lock (or unlock-while-away) until the device is near again.
    public private(set) var isWaitingForReturn = false
    public private(set) var awaySince: Date?

    public init(configuration: ProximityConfiguration = .default) {
        self.configuration = configuration.sanitized
    }

    // MARK: Single-device conveniences

    public var smoothedRSSI: Double? {
        devices.values.compactMap(\.smoothedRSSI).max()
    }

    public var zone: Zone? { devices[Self.defaultDevice]?.zone }

    public func smoothedRSSI(for device: String) -> Double? { devices[device]?.smoothedRSSI }

    // MARK: Inputs

    public mutating func ingest(rssi: Double, at date: Date, device: String = ProximityEngine.defaultDevice) {
        // CoreBluetooth reports 127 when RSSI is unavailable; 0 is never a real reading.
        guard rssi < 0, rssi > -127 else { return }
        var d = devices[device] ?? DeviceSignal()
        if let s = d.smoothedRSSI, let last = d.lastSampleAt,
           date.timeIntervalSince(last) <= configuration.signalTimeout {
            let a = configuration.smoothingFactor
            d.smoothedRSSI = (1 - a) * s + a * rssi
        } else {
            // First sample or signal came back after a gap: start fresh.
            d.smoothedRSSI = rssi
            d.zone = nil
        }
        d.lastSampleAt = date
        devices[device] = d
        updateZone(device)
    }

    public mutating func removeDevice(_ device: String) {
        devices[device] = nil
    }

    public mutating func pause(until date: Date) {
        pausedUntil = date
        awaySince = nil
    }

    public mutating func resume() {
        pausedUntil = nil
        awaySince = nil
    }

    public mutating func screenDidLock() {
        isScreenLocked = true
        awaySince = nil
    }

    /// User unlocked the Mac. If you're still away, disarm so we don't lock again right away.
    public mutating func screenDidUnlock(at now: Date) {
        isScreenLocked = false
        awaySince = nil
        if isAway(at: now) {
            if isArmed { isWaitingForReturn = true }
            isArmed = false
        }
    }

    /// Forget all tracking state (sleep/wake, device changed, Bluetooth reset).
    public mutating func resetTracking() {
        devices.removeAll()
        isArmed = false
        isWaitingForReturn = false
        awaySince = nil
    }

    // MARK: Evaluation

    /// No tracked device has a fresh signal.
    public func isSignalLost(at now: Date) -> Bool {
        devices.values.allSatisfy { $0.isSignalLost(at: now, timeout: configuration.signalTimeout) }
    }

    /// Combined presence according to `policy`.
    public func isAway(at now: Date) -> Bool {
        let t = configuration.signalTimeout
        switch policy {
        case .allAway:
            return !devices.values.contains { $0.isPresent(at: now, timeout: t) }
        case .anyAway:
            let participating = devices.values.filter(\.hasBeenNear)
            guard !participating.isEmpty else { return true }
            return !participating.allSatisfy { $0.isPresent(at: now, timeout: t) }
        }
    }

    public func isPaused(at now: Date) -> Bool {
        if let p = pausedUntil { return now < p }
        return false
    }

    /// Call periodically (every 1–2 s). Returns `.lock` at most once per away period.
    public mutating func evaluate(at now: Date) -> ProximityDecision {
        if let p = pausedUntil, now >= p { pausedUntil = nil }

        if !isAway(at: now) {
            isArmed = true
            isWaitingForReturn = false
            awaySince = nil
            return .none
        }

        guard isEnabled, isBluetoothAvailable, pausedUntil == nil, !isScreenLocked, isArmed else {
            awaySince = nil
            return .none
        }

        let since = awaySince ?? now
        awaySince = since
        if now.timeIntervalSince(since) >= configuration.lockDelay {
            isArmed = false
            isWaitingForReturn = true
            awaySince = nil
            return .lock
        }
        return .none
    }

    public func status(at now: Date) -> ProximityStatus {
        if !isEnabled { return .disabled }
        if let p = pausedUntil, now < p { return .paused(until: p) }
        if !isBluetoothAvailable { return .bluetoothOff }
        if !isAway(at: now) { return .near }
        if !isArmed { return isWaitingForReturn ? .away : .searching }
        let elapsed = awaySince.map { now.timeIntervalSince($0) } ?? 0
        let left = Int(max(0, configuration.lockDelay - elapsed).rounded(.up))
        // "Leaving" when some device still has a (weak) signal; "lost" when none does.
        return isSignalLost(at: now) ? .signalLost(secondsLeft: left) : .leaving(secondsLeft: left)
    }

    private mutating func updateZone(_ key: String) {
        guard var d = devices[key] else { return }
        if let s = d.smoothedRSSI {
            switch d.zone {
            case nil: d.zone = s >= configuration.nearThreshold ? .near : .far
            case .near?: if s < configuration.farThreshold { d.zone = .far }
            case .far?: if s > configuration.nearThreshold { d.zone = .near }
            }
        } else {
            d.zone = nil
        }
        if d.zone == .near { d.hasBeenNear = true }
        devices[key] = d
    }
}
