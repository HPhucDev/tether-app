import XCTest
@testable import TetherCore

final class MultiDeviceTests: XCTestCase {
    private var engine = ProximityEngine()
    private var now = Date(timeIntervalSince1970: 0)
    private var locks = 0

    /// Each second: feed samples for the given devices (nil = no sample) and evaluate.
    private func run(_ seconds: Int, phone: Double?, watch: Double?) {
        for _ in 0..<seconds {
            now += 1
            if let phone { engine.ingest(rssi: phone, at: now, device: "phone") }
            if let watch { engine.ingest(rssi: watch, at: now, device: "watch") }
            if engine.evaluate(at: now) == .lock { locks += 1 }
        }
    }

    override func setUp() {
        engine = ProximityEngine()
        now = Date(timeIntervalSince1970: 0)
        locks = 0
    }

    func testAllAwayDoesNotLockWhileOneDeviceNear() {
        engine.policy = .allAway
        run(5, phone: -50, watch: -50)
        run(60, phone: -90, watch: -50)  // phone left in a drawer, watch on wrist
        XCTAssertEqual(locks, 0)
        XCTAssertEqual(engine.status(at: now), .near)
    }

    func testAllAwayLocksWhenBothLeave() {
        engine.policy = .allAway
        run(5, phone: -50, watch: -50)
        run(30, phone: -90, watch: -90)
        XCTAssertEqual(locks, 1)
    }

    func testAllAwayLocksWhenOneLostAndOtherFar() {
        engine.policy = .allAway
        run(5, phone: -50, watch: -50)
        run(30, phone: nil, watch: -90)
        XCTAssertEqual(locks, 1)
    }

    func testAnyAwayLocksWhenOneLeaves() {
        engine.policy = .anyAway
        run(5, phone: -50, watch: -50)
        run(30, phone: -90, watch: -50)
        XCTAssertEqual(locks, 1)
    }

    func testAnyAwayIgnoresDeviceNeverSeenNear() {
        engine.policy = .anyAway
        // Watch is charging in another room: never near, must not block arming or force locks.
        run(5, phone: -50, watch: -92)
        XCTAssertTrue(engine.isArmed)
        run(60, phone: -50, watch: -92)
        XCTAssertEqual(locks, 0)
        run(30, phone: -90, watch: -92)
        XCTAssertEqual(locks, 1)
    }

    func testSingleDeviceOnlyWatchWorks() {
        run(5, phone: nil, watch: -50)
        run(30, phone: nil, watch: -90)
        XCTAssertEqual(locks, 1)
    }

    func testRemoveDeviceDropsItsInfluence() {
        engine.policy = .allAway
        run(5, phone: -50, watch: -50)
        engine.removeDevice("watch")
        run(30, phone: -90, watch: nil)
        XCTAssertEqual(locks, 1)
    }

    func testPerDeviceSmoothing() {
        engine.ingest(rssi: -50, at: now, device: "phone")
        engine.ingest(rssi: -80, at: now, device: "watch")
        XCTAssertEqual(engine.smoothedRSSI(for: "phone"), -50)
        XCTAssertEqual(engine.smoothedRSSI(for: "watch"), -80)
        XCTAssertEqual(engine.smoothedRSSI, -50)
    }
}
