import CoreBluetooth
import Foundation
import IOBluetooth
import os

/// The two kinds of device Tether can follow. Both can be tracked at the same time.
enum DeviceKind: String, CaseIterable, Identifiable {
    case iPhone
    case watch
    /// AirPods, fitness band, any BLE device you carry.
    case other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .iPhone: return "iPhone"
        case .watch: return "Apple Watch"
        case .other: return "Thiết bị khác"
        }
    }
    var symbol: String {
        switch self {
        case .iPhone: return "iphone"
        case .watch: return "applewatch"
        case .other: return "headphones"
        }
    }
}

struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    var name: String?
    var rssi: Int
    var isApple: Bool
    /// Probably the user's own device: same iCloud account (macOS resolved its private address and knows its name)
    /// or paired with this Mac over Bluetooth.
    var isMine: Bool
    var lastSeen: Date

    /// `lastSeen` is ignored so the UI only refreshes when something visible changed.
    static func == (a: DiscoveredDevice, b: DiscoveredDevice) -> Bool {
        a.id == b.id && a.name == b.name && a.rssi == b.rssi && a.isApple == b.isApple && a.isMine == b.isMine
    }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return isApple ? "Thiết bị Apple" : "Không tên"
    }

    /// Best guess at what kind of device this is, from its name.
    var guessedKind: DeviceKind? {
        let n = (name ?? "").lowercased()
        if n.contains("watch") { return .watch }
        if n.contains("iphone") { return .iPhone }
        if ["airpods", "beats", "band", "buds", "fitbit", "garmin", "whoop"].contains(where: n.contains) { return .other }
        return nil
    }
}

enum BluetoothPower: Equatable {
    case unknown, poweredOn, poweredOff, unauthorized, unsupported
}

enum ConnectionState: Equatable {
    case idle       // no device chosen
    case listening  // hearing the device's advertisements
    case notHeard   // chosen, but nothing heard recently
}

struct DeviceTarget: Equatable {
    var id: UUID
    /// Used to find the device again if its Bluetooth identifier rotates.
    var name: String?
}

/// Passive BLE listener: no app is needed on the iPhone or Watch.
/// Apple devices constantly advertise (Handoff, AirDrop, Continuity…); Tether measures the RSSI of those packets.
/// All CoreBluetooth state lives on `queue`; callbacks are delivered on the main actor.
final class BluetoothService: NSObject {
    var onPowerChange: (@MainActor (BluetoothPower) -> Void)?
    var onConnectionChange: (@MainActor (DeviceKind, ConnectionState) -> Void)?
    var onRSSI: (@MainActor (DeviceKind, Double, Date) -> Void)?
    var onDevices: (@MainActor ([DiscoveredDevice]) -> Void)?
    /// A tracked device was found again under a new Bluetooth identifier.
    var onTargetMoved: (@MainActor (DeviceKind, UUID) -> Void)?

    /// Not heard for this long → state becomes `.notHeard`.
    private let notHeardAfter: TimeInterval = 10
    /// Only re-identify by name after the old identifier has been silent this long.
    private let renameAfter: TimeInterval = 15

    private let log = Logger(subsystem: "com.simple.tether", category: "bluetooth")
    private let queue = DispatchQueue(label: "com.simple.tether.bluetooth", qos: .utility)

    // Queue-confined state
    private var central: CBCentralManager!
    private var targets: [DeviceKind: DeviceTarget] = [:]
    private var lastHeard: [DeviceKind: Date] = [:]
    private var samples: [DeviceKind: [Int]] = [:]
    private var states: [DeviceKind: ConnectionState] = [:]
    private var discoveryActive = false
    private var discovered: [UUID: DiscoveredDevice] = [:]
    private var isScanning = false
    /// Screen locked or Mac asleep: nothing to decide, so don't scan at all.
    private var isSuspended = false
    private var pairedNames: Set<String> = []
    private var lastDeliveredDevices: [DiscoveredDevice] = []
    private var tickTimer: DispatchSourceTimer?

    override init() {
        super.init()
        queue.sync {
            central = CBCentralManager(delegate: self, queue: queue, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
        startTicking()
    }

    // MARK: Public API (thread-safe)

    func setTarget(_ target: DeviceTarget?, for kind: DeviceKind) {
        queue.async {
            guard self.targets[kind] != target else { return }
            self.targets[kind] = target
            self.samples[kind] = nil
            self.lastHeard[kind] = nil
            self.log.info("\(kind.rawValue, privacy: .public) target: \(target?.id.uuidString ?? "none", privacy: .public)")
            self.updateState(kind, now: Date())
            self.updateScanning()
        }
    }

    /// Full device list (Devices tab / onboarding).
    func setDiscoveryActive(_ isActive: Bool) {
        queue.async {
            guard self.discoveryActive != isActive else { return }
            self.discoveryActive = isActive
            if isActive { self.pairedNames = Self.loadPairedNames() }
            if !isActive {
                self.discovered.removeAll()
                self.lastDeliveredDevices = []
            }
            self.updateScanning()
        }
    }

    /// Stop all scanning while the screen is locked / the Mac sleeps; resume afterwards.
    func setSuspended(_ suspended: Bool) {
        queue.async {
            guard self.isSuspended != suspended else { return }
            self.isSuspended = suspended
            self.samples.removeAll()
            self.log.info("Scanning \(suspended ? "suspended" : "resumed", privacy: .public)")
            self.updateScanning()
        }
    }

    /// After wake: restart scanning so CoreBluetooth reports fresh packets.
    func restart() {
        queue.async {
            self.isScanning = false
            self.central.stopScan()
            self.samples.removeAll()
            self.lastHeard.removeAll()
            self.updateScanning()
        }
    }

    // MARK: Queue-confined logic

    private func updateScanning() {
        guard central.state == .poweredOn else { isScanning = false; return }
        let wanted = !isSuspended && (discoveryActive || !targets.isEmpty)
        guard wanted != isScanning else { return }
        isScanning = wanted
        if wanted {
            startScanWindow()
        } else {
            central.stopScan()
        }
        log.debug("Scanning: \(wanted)")
    }

    /// Scans WITHOUT duplicates and restarts every tick. The Bluetooth controller then filters repeats in
    /// hardware and reports each nearby device about once per 1.5 s window, instead of waking Tether
    /// hundreds of times per second (AllowDuplicates). One fresh RSSI per device per window is all we need.
    private func startScanWindow() {
        central.stopScan()
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func updateState(_ kind: DeviceKind, now: Date) {
        let state: ConnectionState
        if targets[kind] == nil {
            state = .idle
        } else if let t = lastHeard[kind], now.timeIntervalSince(t) <= notHeardAfter {
            state = .listening
        } else {
            state = .notHeard
        }
        guard states[kind] != state else { return }
        states[kind] = state
        deliver { $0.onConnectionChange?(kind, state) }
    }

    private func startTicking() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1.5, repeating: 1.5, leeway: .milliseconds(500))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        tickTimer = t
    }

    /// Every 1.5 s: deliver one averaged RSSI per tracked device and refresh the device list.
    private func tick() {
        let now = Date()
        if isScanning, central.state == .poweredOn { startScanWindow() }
        for kind in DeviceKind.allCases {
            if let values = samples[kind], !values.isEmpty {
                let avg = Double(values.reduce(0, +)) / Double(values.count)
                samples[kind]?.removeAll(keepingCapacity: true)
                deliver { $0.onRSSI?(kind, avg, now) }
            }
            updateState(kind, now: now)
        }
        if discoveryActive {
            let cutoff = now.addingTimeInterval(-10)
            discovered = discovered.filter { $0.value.lastSeen > cutoff }
            let list = discovered.values.sorted { $0.rssi > $1.rssi }
            if list != lastDeliveredDevices {
                lastDeliveredDevices = list
                deliver { $0.onDevices?(list) }
            }
        }
    }

    private func deliver(_ body: @escaping @MainActor (BluetoothService) -> Void) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { body(self) }
        }
    }

    /// Names of devices paired with this Mac in System Settings › Bluetooth.
    private static func loadPairedNames() -> Set<String> {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return Set(devices.compactMap(\.name))
    }

    private func power(from state: CBManagerState) -> BluetoothPower {
        switch state {
        case .poweredOn: return .poweredOn
        case .poweredOff, .resetting: return .poweredOff
        case .unauthorized: return .unauthorized
        case .unsupported: return .unsupported
        default: return .unknown
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let p = power(from: central.state)
        log.info("Bluetooth state: \(String(describing: p), privacy: .public)")
        deliver { $0.onPowerChange?(p) }
        isScanning = false
        samples.removeAll()
        lastHeard.removeAll()
        updateScanning()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // With duplicates on this fires hundreds of times per second: keep the hot path cheap.
        let rssi = RSSI.intValue
        guard rssi < 0, rssi > -127 else { return }
        let id = peripheral.identifier
        let now = Date()

        var matched = false
        for (kind, target) in targets where target.id == id {
            samples[kind, default: []].append(rssi)
            lastHeard[kind] = now
            matched = true
        }

        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name

        // Identifier rotated? Adopt a device with the same (specific) name once the old one went silent.
        if !matched, let name, !name.isEmpty {
            for (kind, target) in targets where target.name == name && name != "iPhone" && name != "Apple Watch" {
                let silentFor = lastHeard[kind].map { now.timeIntervalSince($0) } ?? .infinity
                guard silentFor > renameAfter else { continue }
                log.notice("\(kind.rawValue, privacy: .public) re-identified by name as \(id.uuidString, privacy: .public)")
                targets[kind]?.id = id
                samples[kind] = [rssi]
                lastHeard[kind] = now
                deliver { $0.onTargetMoved?(kind, id) }
            }
        }

        guard discoveryActive else { return }
        let mfg = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let isApple = mfg.map { $0.count >= 2 && $0[$0.startIndex] == 0x4C && $0[$0.startIndex + 1] == 0x00 } ?? false
        // Only list devices a user could recognise.
        guard isApple || name != nil || matched else { return }
        // Same-iCloud Apple devices don't put their name in the packet, yet macOS knows it.
        let resolvedByICloud = isApple && advertisedName == nil && peripheral.name != nil
        let isMine = resolvedByICloud || name.map(pairedNames.contains) == true
        var d = discovered[id] ?? DiscoveredDevice(id: id, name: name, rssi: rssi, isApple: isApple, isMine: isMine, lastSeen: now)
        d.isMine = d.isMine || isMine
        d.rssi = rssi
        d.lastSeen = now
        if let name { d.name = name }
        d.isApple = d.isApple || isApple
        discovered[id] = d
    }
}
