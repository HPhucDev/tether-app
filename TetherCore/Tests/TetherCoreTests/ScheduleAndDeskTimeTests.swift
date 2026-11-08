import XCTest
@testable import TetherCore

final class ActiveScheduleTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // 2026-11-09 is a Monday, 2026-11-14 a Saturday.
    func testWorkHours() {
        let s = ActiveSchedule.workHours
        XCTAssertTrue(s.isActive(at: date(2026, 11, 9, 8), calendar: cal))
        XCTAssertTrue(s.isActive(at: date(2026, 11, 9, 17, 59), calendar: cal))
        XCTAssertFalse(s.isActive(at: date(2026, 11, 9, 18), calendar: cal))
        XCTAssertFalse(s.isActive(at: date(2026, 11, 9, 7, 59), calendar: cal))
        XCTAssertFalse(s.isActive(at: date(2026, 11, 14, 10), calendar: cal))
    }

    func testOvernightBelongsToStartDay() {
        // Friday 22:00 → 06:00.
        let s = ActiveSchedule(weekdays: [6], startMinute: 22 * 60, endMinute: 6 * 60)
        XCTAssertTrue(s.isActive(at: date(2026, 11, 13, 23), calendar: cal))     // Fri night
        XCTAssertTrue(s.isActive(at: date(2026, 11, 14, 5, 30), calendar: cal))  // Sat early morning
        XCTAssertFalse(s.isActive(at: date(2026, 11, 14, 23), calendar: cal))    // Sat night
        XCTAssertFalse(s.isActive(at: date(2026, 11, 13, 5), calendar: cal))     // Fri early morning
    }

    func testSameStartAndEndMeansAllDay() {
        let s = ActiveSchedule(weekdays: [2], startMinute: 0, endMinute: 0)
        XCTAssertTrue(s.isActive(at: date(2026, 11, 9, 3), calendar: cal))
        XCTAssertFalse(s.isActive(at: date(2026, 11, 10, 3), calendar: cal))
    }

    func testNoDaysIsNeverActive() {
        let s = ActiveSchedule(weekdays: [], startMinute: 0, endMinute: 0)
        XCTAssertFalse(s.isActive(at: date(2026, 11, 9, 12), calendar: cal))
        XCTAssertNil(s.nextStart(after: date(2026, 11, 9, 12), calendar: cal))
    }

    func testNextStartSkipsWeekend() {
        let s = ActiveSchedule.workHours
        XCTAssertEqual(s.nextStart(after: date(2026, 11, 13, 19), calendar: cal), date(2026, 11, 16, 8))
        XCTAssertEqual(s.nextStart(after: date(2026, 11, 9, 7), calendar: cal), date(2026, 11, 9, 8))
    }
}

final class DeskTimeTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return c
    }()

    private func run(_ d: inout DeskTime, present: Bool, from start: Date, seconds: Int) -> Date {
        var t = start
        for _ in 0..<seconds {
            t = t.addingTimeInterval(1)
            d.update(present: present, at: t, calendar: cal)
        }
        return t
    }

    func testCountsOnlyPresentTime() {
        var d = DeskTime()
        let t0 = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!
        d.update(present: true, at: t0, calendar: cal)
        var t = run(&d, present: true, from: t0, seconds: 600)
        t = run(&d, present: false, from: t, seconds: 300)
        _ = run(&d, present: true, from: t, seconds: 60)
        XCTAssertEqual(d.seconds(on: t0, calendar: cal), 660, accuracy: 1)
    }

    func testIgnoresLongGaps() {
        var d = DeskTime()
        let t0 = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!
        d.update(present: true, at: t0, calendar: cal)
        d.update(present: true, at: t0.addingTimeInterval(3600), calendar: cal)   // slept for an hour
        XCTAssertEqual(d.seconds(on: t0, calendar: cal), 0)
    }

    func testSplitsAcrossMidnight() {
        var d = DeskTime()
        let t0 = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 23, minute: 59, second: 55))!
        d.update(present: true, at: t0, calendar: cal)
        d.update(present: true, at: t0.addingTimeInterval(10), calendar: cal)
        XCTAssertEqual(d.seconds(on: t0, calendar: cal), 5, accuracy: 0.001)
        XCTAssertEqual(d.seconds(on: t0.addingTimeInterval(10), calendar: cal), 5, accuracy: 0.001)
    }

    func testBreakReminderAfterContinuousSitting() {
        var d = DeskTime()
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        d.update(present: true, at: t0, calendar: cal)
        var t = run(&d, present: true, from: t0, seconds: 59)
        XCTAssertFalse(d.shouldRemind(every: 60, at: t))
        t = run(&d, present: true, from: t, seconds: 1)
        XCTAssertTrue(d.shouldRemind(every: 60, at: t))
        XCTAssertFalse(d.shouldRemind(every: 60, at: t))          // once per interval
        t = run(&d, present: true, from: t, seconds: 60)
        XCTAssertTrue(d.shouldRemind(every: 60, at: t))           // again after another interval
    }

    func testShortAbsenceKeepsSittingLongOneResets() {
        var d = DeskTime()
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        d.update(present: true, at: t0, calendar: cal)
        var t = run(&d, present: true, from: t0, seconds: 100)
        t = run(&d, present: false, from: t, seconds: 30)          // grabbed a coffee
        t = run(&d, present: true, from: t, seconds: 1)
        XCTAssertEqual(d.sittingDuration(at: t), 131, accuracy: 1)
        t = run(&d, present: false, from: t, seconds: 150)         // real break
        t = run(&d, present: true, from: t, seconds: 1)
        XCTAssertEqual(d.sittingDuration(at: t), 0, accuracy: 1)
    }

    func testLastDaysOldestFirst() {
        var d = DeskTime()
        let t0 = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 10))!
        d.update(present: true, at: t0, calendar: cal)
        d.update(present: true, at: t0.addingTimeInterval(5), calendar: cal)
        let days = d.lastDays(7, endingAt: t0, calendar: cal)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.last?.seconds ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(days.first?.seconds, 0)
    }
}
