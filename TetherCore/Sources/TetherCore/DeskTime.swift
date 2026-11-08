import Foundation

/// Time spent at the desk (a tracked device near the Mac, screen unlocked), per calendar day,
/// plus a "you've been sitting a while" timer for break reminders.
public struct DeskTime: Equatable, Codable, Sendable {
    /// Seconds at the desk, keyed by "yyyy-MM-dd" in the user's calendar.
    public private(set) var secondsByDay: [String: TimeInterval] = [:]
    /// Days kept; older ones are dropped.
    public var retentionDays = 30
    /// Gaps longer than this between updates (sleep, app not running) are not counted.
    public var maxGap: TimeInterval = 10
    /// Being away (or locked) at least this long ends a sitting.
    public var breakAfterAway: TimeInterval = 120

    public private(set) var lastUpdate: Date?
    /// Start of the current sitting, nil while away.
    public private(set) var sittingSince: Date?
    public private(set) var awaySince: Date?
    /// Last time a break reminder fired during this sitting.
    public private(set) var lastReminder: Date?

    public init() {}

    /// Call about once per second. `present` = a device is near and the screen is unlocked.
    public mutating func update(present: Bool, at now: Date, calendar: Calendar = .current) {
        defer { lastUpdate = now }
        if present {
            awaySince = nil
            if sittingSince == nil { sittingSince = now; lastReminder = nil }
            if let last = lastUpdate, now > last, now.timeIntervalSince(last) <= maxGap {
                add(now.timeIntervalSince(last), endingAt: now, calendar: calendar)
            }
        } else {
            if awaySince == nil { awaySince = now }
            if let a = awaySince, now.timeIntervalSince(a) >= breakAfterAway {
                sittingSince = nil
                lastReminder = nil
            }
        }
    }

    /// True once per `interval` of continuous sitting. Call after `update`.
    public mutating func shouldRemind(every interval: TimeInterval, at now: Date) -> Bool {
        guard interval > 0, awaySince == nil, let since = sittingSince else { return false }
        let reference = lastReminder ?? since
        guard now.timeIntervalSince(reference) >= interval else { return false }
        lastReminder = now
        return true
    }

    /// Minutes sitting continuously right now (0 when away).
    public func sittingDuration(at now: Date) -> TimeInterval {
        guard awaySince == nil, let since = sittingSince else { return 0 }
        return max(0, now.timeIntervalSince(since))
    }

    public func seconds(on date: Date, calendar: Calendar = .current) -> TimeInterval {
        secondsByDay[Self.key(for: date, calendar: calendar)] ?? 0
    }

    /// The last `count` days ending today, oldest first.
    public func lastDays(_ count: Int, endingAt now: Date, calendar: Calendar = .current) -> [(day: Date, seconds: TimeInterval)] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            return (day, seconds(on: day, calendar: calendar))
        }
    }

    public mutating func clear() {
        self = DeskTime()
    }

    // MARK: Private

    /// Splits time across midnight so each day gets its own share.
    private mutating func add(_ interval: TimeInterval, endingAt end: Date, calendar: Calendar) {
        let start = end.addingTimeInterval(-interval)
        let midnight = calendar.startOfDay(for: end)
        if start < midnight {
            bump(midnight.timeIntervalSince(start), key: Self.key(for: start, calendar: calendar))
            bump(end.timeIntervalSince(midnight), key: Self.key(for: end, calendar: calendar))
        } else {
            bump(interval, key: Self.key(for: end, calendar: calendar))
        }
        prune(before: end, calendar: calendar)
    }

    private mutating func bump(_ seconds: TimeInterval, key: String) {
        secondsByDay[key, default: 0] += seconds
    }

    private mutating func prune(before now: Date, calendar: Calendar) {
        guard secondsByDay.count > retentionDays,
              let cutoff = calendar.date(byAdding: .day, value: -retentionDays, to: calendar.startOfDay(for: now)) else { return }
        let cutoffKey = Self.key(for: cutoff, calendar: calendar)
        secondsByDay = secondsByDay.filter { $0.key > cutoffKey }
    }

    static func key(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
