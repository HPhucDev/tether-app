import Foundation

enum LockReason: String, Codable {
    case walkedAway
    case signalLost
    case bluetoothOff
    case test
    case shortcut

    var title: String {
        switch self {
        case .walkedAway: return "Thiết bị đi xa"
        case .signalLost: return "Mất tín hiệu"
        case .bluetoothOff: return "Bluetooth bị tắt"
        case .test: return "Khoá thử"
        case .shortcut: return "Từ Phím tắt"
        }
    }

    var symbol: String {
        switch self {
        case .walkedAway: return "figure.walk"
        case .signalLost: return "antenna.radiowaves.left.and.right.slash"
        case .bluetoothOff: return "exclamationmark.triangle"
        case .test: return "hand.tap"
        case .shortcut: return "square.2.layers.3d"
        }
    }
}

struct LockEvent: Codable, Identifiable, Equatable {
    struct Reading: Codable, Equatable {
        var kind: String       // DeviceKind.rawValue
        var name: String?
        var rssi: Double?      // nil = no signal
    }

    var id = UUID()
    var date: Date
    var reason: LockReason
    var method: String
    var readings: [Reading]
}

/// Last 50 locks, stored only in this Mac's UserDefaults. Never leaves the device.
@MainActor
final class LockHistory: ObservableObject {
    static let limit = 50
    @Published private(set) var events: [LockEvent] = []

    private let defaults: UserDefaults
    private let key = "lockHistory"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([LockEvent].self, from: data) {
            events = decoded
        }
    }

    func record(_ event: LockEvent) {
        events.insert(event, at: 0)
        if events.count > Self.limit { events.removeLast(events.count - Self.limit) }
        save()
    }

    func clear() {
        events = []
        defaults.removeObject(forKey: key)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: key)
        }
    }
}
