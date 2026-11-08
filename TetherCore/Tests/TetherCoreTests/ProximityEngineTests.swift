import XCTest
@testable import TetherCore

/// Drives the engine with one sample + one evaluation per simulated second.
private struct Simulator {
    var engine = ProximityEngine()
    var now = Date(timeIntervalSince1970: 1_000_000)
    var lockTimes: [TimeInterval] = []
    let start: Date

    init(configuration: ProximityConfiguration = .default) {
        engine = ProximityEngine(configuration: configuration)
        start = now
    }

    var elapsed: TimeInterval { now.timeIntervalSince(start) }

    /// `rssi == nil` means no sample this second (signal lost).
    mutating func run(seconds: Int, rssi: Double?) {
        for _ in 0..<seconds {
            now += 1
            if let r = rssi { engine.ingest(rssi: r, at: now) }
            if engine.evaluate(at: now) == .lock { lockTimes.append(elapsed) }
        }
    }

    mutating func run(seconds: Int, pattern: [Double]) {
        for i in 0..<seconds {
            now += 1
            engine.ingest(rssi: pattern[i % pattern.count], at: now)
            if engine.evaluate(at: now) == .lock { lockTimes.append(elapsed) }
        }
    }
}

final class ProximityEngineTests: XCTestCase {

    func testDoesNotLockOnLaunchWhenDeviceNeverSeen() {
        var sim = Simulator()
        sim.run(seconds: 120, rssi: nil)
        XCTAssertTrue(sim.lockTimes.isEmpty)
        XCTAssertEqual(sim.engine.status(at: sim.now), .searching)
    }

    func testDoesNotLockOnLaunchWhenDeviceStartsFar() {
        var sim = Simulator()
        sim.run(seconds: 120, rssi: -90)
        XCTAssertTrue(sim.lockTimes.isEmpty)
        XCTAssertFalse(sim.engine.isArmed)
    }

    func testFirstSampleBetweenThresholdsDoesNotArm() {
        var sim = Simulator()
        sim.run(seconds: 30, rssi: -70)
        XCTAssertFalse(sim.engine.isArmed)
        XCTAssertEqual(sim.engine.status(at: sim.now), .searching)
    }

    func testLocksOnceAfterDelayWhenWalkingAway() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        XCTAssertEqual(sim.engine.status(at: sim.now), .near)
        XCTAssertTrue(sim.engine.isArmed)

        let leaveAt = sim.elapsed
        sim.run(seconds: 60, rssi: -90)
        XCTAssertEqual(sim.lockTimes.count, 1, "must lock exactly once while staying away")
        let delay = sim.lockTimes[0] - leaveAt
        XCTAssertGreaterThanOrEqual(delay, 8)
        XCTAssertLessThanOrEqual(delay, 13)
        XCTAssertEqual(sim.engine.status(at: sim.now), .away)
    }

    func testLeavingStatusCountsDown() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        sim.run(seconds: 4, rssi: -95)  // EMA crosses -75 on the 3rd far sample
        guard case .leaving(let left) = sim.engine.status(at: sim.now) else {
            return XCTFail("expected leaving, got \(sim.engine.status(at: sim.now))")
        }
        XCTAssertTrue((1...8).contains(left))
    }

    func testOscillationAboveFarThresholdNeverLocks() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -55)
        sim.run(seconds: 300, pattern: [-66, -74, -68, -73, -64, -72])
        XCTAssertTrue(sim.lockTimes.isEmpty)
        XCTAssertEqual(sim.engine.zone, .near)
    }

    func testHysteresisKeepsFarUntilAboveNearThreshold() {
        var config = ProximityConfiguration.default
        config.lockDelay = 1000  // isolate zone behaviour
        var sim = Simulator(configuration: config)
        sim.run(seconds: 5, rssi: -50)
        sim.run(seconds: 10, rssi: -90)
        XCTAssertEqual(sim.engine.zone, .far)
        // Hovering between thresholds must not flip back to near.
        sim.run(seconds: 30, pattern: [-68, -72, -70])
        XCTAssertEqual(sim.engine.zone, .far)
        sim.run(seconds: 10, rssi: -55)
        XCTAssertEqual(sim.engine.zone, .near)
    }

    func testSignalLossCountsAsAway() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        sim.run(seconds: 30, rssi: nil)
        XCTAssertEqual(sim.lockTimes.count, 1)
        let afterLoss = sim.lockTimes[0] - 5
        // 6 s timeout + 8 s delay
        XCTAssertGreaterThanOrEqual(afterLoss, 14)
        XCTAssertLessThanOrEqual(afterLoss, 16)
    }

    func testSignalLostStatus() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        sim.run(seconds: 8, rssi: nil)
        guard case .signalLost = sim.engine.status(at: sim.now) else {
            return XCTFail("expected signalLost, got \(sim.engine.status(at: sim.now))")
        }
    }

    func testShortDropoutDoesNotLock() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        for _ in 0..<10 {
            sim.run(seconds: 5, rssi: nil)  // shorter than timeout + delay
            sim.run(seconds: 3, rssi: -50)
        }
        XCTAssertTrue(sim.lockTimes.isEmpty)
    }

    func testNoRelockAfterUnlockWhilePhoneStillAway() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        sim.run(seconds: 30, rssi: -90)
        XCTAssertEqual(sim.lockTimes.count, 1)

        sim.engine.screenDidLock()
        sim.run(seconds: 10, rssi: -90)
        sim.engine.screenDidUnlock(at: sim.now)  // user typed password, phone forgotten elsewhere
        sim.run(seconds: 300, rssi: -90)
        XCTAssertEqual(sim.lockTimes.count, 1)
        XCTAssertEqual(sim.engine.status(at: sim.now), .away)
    }

    func testManualLockThenUnlockWhileAwayDisarms() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        sim.engine.screenDidLock()
        sim.run(seconds: 60, rssi: -90)
        XCTAssertTrue(sim.lockTimes.isEmpty, "already locked screen is ignored")
        sim.engine.screenDidUnlock(at: sim.now)
        sim.run(seconds: 60, rssi: -90)
        XCTAssertTrue(sim.lockTimes.isEmpty)
    }

    func testRearmsWhenDeviceReturns() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        sim.run(seconds: 30, rssi: -90)
        sim.run(seconds: 10, rssi: -50)
        XCTAssertTrue(sim.engine.isArmed)
        sim.run(seconds: 30, rssi: -90)
        XCTAssertEqual(sim.lockTimes.count, 2)
    }

    func testSleepWakeResetRequiresNearAgain() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        sim.engine.resetTracking()  // willSleep / didWake
        sim.run(seconds: 60, rssi: -90)
        XCTAssertTrue(sim.lockTimes.isEmpty)
        XCTAssertEqual(sim.engine.status(at: sim.now), .searching)
    }

    func testPauseSuppressesLockAndRestartsDelayAfterExpiry() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        sim.engine.pause(until: sim.now + 30 * 60)
        sim.run(seconds: 10, rssi: -90)
        if case .paused = sim.engine.status(at: sim.now) {} else { XCTFail("expected paused") }
        sim.run(seconds: 30 * 60 - 10, rssi: -90)
        XCTAssertTrue(sim.lockTimes.isEmpty)

        let pauseEnd = sim.elapsed
        sim.run(seconds: 20, rssi: -90)
        XCTAssertEqual(sim.lockTimes.count, 1)
        XCTAssertGreaterThanOrEqual(sim.lockTimes[0] - pauseEnd, 8)
    }

    func testResumeEndsPause() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        sim.engine.pause(until: sim.now + 3600)
        sim.engine.resume()
        sim.run(seconds: 30, rssi: -90)
        XCTAssertEqual(sim.lockTimes.count, 1)
    }

    func testDisabledNeverLocks() {
        var sim = Simulator()
        sim.engine.isEnabled = false
        sim.run(seconds: 5, rssi: -50)
        sim.run(seconds: 60, rssi: -90)
        XCTAssertTrue(sim.lockTimes.isEmpty)
        XCTAssertEqual(sim.engine.status(at: sim.now), .disabled)
    }

    func testBluetoothUnavailableNeverLocks() {
        var sim = Simulator()
        sim.run(seconds: 5, rssi: -50)
        sim.engine.isBluetoothAvailable = false
        sim.run(seconds: 60, rssi: nil)
        XCTAssertTrue(sim.lockTimes.isEmpty)
        XCTAssertEqual(sim.engine.status(at: sim.now), .bluetoothOff)
    }

    func testIgnoresInvalidRSSI() {
        var engine = ProximityEngine()
        let t = Date()
        engine.ingest(rssi: 127, at: t)
        engine.ingest(rssi: 0, at: t)
        XCTAssertNil(engine.smoothedRSSI)
    }

    func testEMASmoothing() {
        var engine = ProximityEngine()
        let t = Date()
        engine.ingest(rssi: -50, at: t)
        engine.ingest(rssi: -60, at: t + 1)
        XCTAssertEqual(engine.smoothedRSSI!, -53, accuracy: 0.0001)
    }

    func testSanitizedConfigurationKeepsNearAboveFar() {
        var engine = ProximityEngine()
        engine.configuration = ProximityConfiguration(farThreshold: -60, nearThreshold: -70)
        XCTAssertGreaterThan(engine.configuration.nearThreshold, engine.configuration.farThreshold)
    }
}
