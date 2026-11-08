import XCTest
@testable import TetherCore

final class RSSIHistoryTests: XCTestCase {
    func testKeepsOnlyWindowInOrder() {
        var h = RSSIHistory(window: 60, capacity: 100)
        let t0 = Date(timeIntervalSince1970: 0)
        for i in 0..<90 { h.append(RSSISample(date: t0 + Double(i), rssi: -Double(i))) }
        let now = t0 + 89
        let s = h.samples(asOf: now)
        XCTAssertEqual(s.first?.date, t0 + 29)
        XCTAssertEqual(s.last?.date, now)
        XCTAssertEqual(s.count, 61)
        XCTAssertEqual(s.map(\.date), s.map(\.date).sorted())
    }

    func testWrapsAroundCapacity() {
        var h = RSSIHistory(window: 1000, capacity: 10)
        let t0 = Date(timeIntervalSince1970: 0)
        for i in 0..<25 { h.append(RSSISample(date: t0 + Double(i), rssi: -50)) }
        let s = h.samples(asOf: t0 + 24)
        XCTAssertEqual(s.count, 10)
        XCTAssertEqual(s.first?.date, t0 + 15)
        XCTAssertEqual(s.last?.date, t0 + 24)
    }
}

final class CalibrationTests: XCTestCase {
    func testThresholdsBetweenPositions() throws {
        let t = try XCTUnwrap(Calibration.thresholds(deskRSSI: -50, awayRSSI: -85))
        XCTAssertLessThan(t.far, t.near)
        XCTAssertGreaterThan(t.far, -85)
        XCTAssertLessThan(t.near, -50)
    }

    func testSmallGapStillOrdered() throws {
        let t = try XCTUnwrap(Calibration.thresholds(deskRSSI: -60, awayRSSI: -68))
        XCTAssertLessThan(t.far, t.near)
    }

    func testRejectsIndistinguishablePositions() {
        XCTAssertNil(Calibration.thresholds(deskRSSI: -70, awayRSSI: -73))
        XCTAssertNil(Calibration.thresholds(deskRSSI: -80, awayRSSI: -60))
    }

    func testAverageIgnoresInvalid() {
        XCTAssertEqual(Calibration.average([-50, -60, 127, 0]), -55)
        XCTAssertNil(Calibration.average([]))
    }

    func testLabelsAndBars() {
        XCTAssertEqual(DistanceLabel(rssi: -50), .near)
        XCTAssertEqual(DistanceLabel(rssi: -70), .medium)
        XCTAssertEqual(DistanceLabel(rssi: -90), .far)
        XCTAssertEqual(SignalStrength.bars(rssi: nil), 0)
        XCTAssertEqual(SignalStrength.bars(rssi: -50), 4)
        XCTAssertEqual(SignalStrength.bars(rssi: -90), 0)
    }
}

final class DistanceEstimateTests: XCTestCase {
    func testMetres() {
        XCTAssertEqual(DistanceEstimate.metres(rssi: -59), 1, accuracy: 0.001)
        XCTAssertEqual(DistanceEstimate.metres(rssi: -75), 4.37, accuracy: 0.05)
        XCTAssertGreaterThan(DistanceEstimate.metres(rssi: -90), DistanceEstimate.metres(rssi: -80))
    }

    func testText() {
        XCTAssertEqual(DistanceEstimate.text(rssi: -45), "< 1 m")
        XCTAssertEqual(DistanceEstimate.text(rssi: -58), "≈ 1 m")
        XCTAssertEqual(DistanceEstimate.text(rssi: -65), "≈ 1,5 m")
        XCTAssertEqual(DistanceEstimate.text(rssi: -75), "≈ 4 m")
        XCTAssertEqual(DistanceEstimate.text(rssi: -100), "> 20 m")
    }
}
