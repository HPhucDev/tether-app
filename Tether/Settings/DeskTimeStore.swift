import Foundation
import TetherCore

/// Persists `DeskTime` in this Mac's UserDefaults. Like the lock history, it never leaves the device.
@MainActor
final class DeskTimeStore: ObservableObject {
    @Published private(set) var deskTime: DeskTime

    private let defaults: UserDefaults
    private let key = "deskTime"
    private var lastSave = Date.distantPast

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        deskTime = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(DeskTime.self, from: $0) } ?? DeskTime()
    }

    /// Feeds one tick. Returns true when a break reminder is due.
    func update(present: Bool, at now: Date, remindEvery minutes: Int?) -> Bool {
        deskTime.update(present: present, at: now)
        let remind = minutes.map { deskTime.shouldRemind(every: TimeInterval($0 * 60), at: now) } ?? false
        // Writing every second would be wasteful; a minute of lost data after a crash is fine.
        if now.timeIntervalSince(lastSave) >= 60 { save(at: now) }
        return remind
    }

    func today(at now: Date = Date()) -> TimeInterval { deskTime.seconds(on: now) }

    func lastDays(_ count: Int, at now: Date = Date()) -> [(day: Date, seconds: TimeInterval)] {
        deskTime.lastDays(count, endingAt: now)
    }

    func clear() {
        deskTime.clear()
        defaults.removeObject(forKey: key)
    }

    func save(at now: Date = Date()) {
        lastSave = now
        if let data = try? JSONEncoder().encode(deskTime) { defaults.set(data, forKey: key) }
    }
}

enum DurationText {
    /// "3 giờ 12 phút", "45 phút", "0 phút".
    static func short(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) phút" }
        return m == 0 ? "\(h) giờ" : "\(h) giờ \(m) phút"
    }
}
