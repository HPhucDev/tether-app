import Foundation

/// "Only protect during these hours": weekdays plus a daily time window.
/// Times are minutes after midnight. An end before the start means the window
/// runs overnight (e.g. 22:00 → 06:00) and belongs to the day it starts on.
public struct ActiveSchedule: Equatable, Codable, Sendable {
    /// Calendar weekday numbers (1 = Sunday … 7 = Saturday).
    public var weekdays: Set<Int>
    public var startMinute: Int
    public var endMinute: Int

    public init(weekdays: Set<Int>, startMinute: Int, endMinute: Int) {
        self.weekdays = weekdays
        self.startMinute = Self.clamp(startMinute)
        self.endMinute = Self.clamp(endMinute)
    }

    /// Monday–Friday, 08:00–18:00.
    public static let workHours = ActiveSchedule(weekdays: [2, 3, 4, 5, 6], startMinute: 8 * 60, endMinute: 18 * 60)

    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard !weekdays.isEmpty else { return false }
        let weekday = calendar.component(.weekday, from: date)
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

        if startMinute == endMinute { return weekdays.contains(weekday) }   // all day
        if startMinute < endMinute {
            return weekdays.contains(weekday) && minute >= startMinute && minute < endMinute
        }
        // Overnight: the evening part belongs to today, the early-morning part to yesterday.
        if minute >= startMinute { return weekdays.contains(weekday) }
        if minute < endMinute { return weekdays.contains(Self.previous(weekday)) }
        return false
    }

    /// Next moment the schedule switches on, searching up to 8 days ahead (nil if never).
    public func nextStart(after date: Date, calendar: Calendar = .current) -> Date? {
        guard !weekdays.isEmpty else { return nil }
        let today = calendar.startOfDay(for: date)
        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let start = calendar.date(byAdding: .minute, value: startMinute, to: day) else { continue }
            if start > date, weekdays.contains(calendar.component(.weekday, from: day)) { return start }
        }
        return nil
    }

    private static func previous(_ weekday: Int) -> Int { weekday == 1 ? 7 : weekday - 1 }
    private static func clamp(_ m: Int) -> Int { min(max(m, 0), 24 * 60 - 1) }
}
