import Foundation

public enum Calibration {
    /// Minimum dB gap between the desk and away positions for a usable calibration.
    public static let minimumGap: Double = 6

    public static func average(_ values: [Double]) -> Double? {
        let valid = values.filter { $0 < 0 && $0 > -127 }
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0, +) / Double(valid.count)
    }

    /// Derives (far, near) thresholds from the average RSSI at the desk and at the spot where the Mac should lock.
    /// Returns nil when the two positions are too close to tell apart.
    public static func thresholds(deskRSSI: Double, awayRSSI: Double) -> (far: Double, near: Double)? {
        let gap = deskRSSI - awayRSSI
        guard gap >= minimumGap else { return nil }
        let far = awayRSSI + gap * 0.3
        let near = min(far + max(4, gap * 0.25), deskRSSI - 2)
        return (far.rounded(), near.rounded())
    }
}

/// Human-friendly labels for RSSI values.
public enum DistanceLabel: String, Sendable {
    case near = "Gần"
    case medium = "Vừa"
    case far = "Xa"

    public init(rssi: Double) {
        switch rssi {
        case (-60)...: self = .near
        case (-75)...: self = .medium
        default: self = .far
        }
    }
}

public enum SignalStrength {
    /// 0…4 bars.
    public static func bars(rssi: Double?) -> Int {
        guard let r = rssi else { return 0 }
        switch r {
        case (-55)...: return 4
        case (-65)...: return 3
        case (-75)...: return 2
        case (-85)...: return 1
        default: return 0
        }
    }
}

/// Rough RSSI → metres conversion (log-distance path loss). Only an estimate:
/// walls, bodies and pockets easily shift RSSI by 10 dB or more.
public enum DistanceEstimate {
    /// Typical RSSI of an iPhone/Watch at 1 m.
    public static let rssiAtOneMetre: Double = -59
    /// Indoor path-loss exponent.
    public static let pathLossExponent: Double = 2.5

    public static func metres(rssi: Double) -> Double {
        pow(10, (rssiAtOneMetre - rssi) / (10 * pathLossExponent))
    }

    /// "< 1 m", "≈ 1,5 m", "≈ 4 m", "> 20 m"
    public static func text(rssi: Double) -> String {
        let m = metres(rssi: rssi)
        if m < 0.75 { return "< 1 m" }
        if m > 20 { return "> 20 m" }
        if m < 3 {
            let rounded = (m * 2).rounded() / 2  // nearest 0.5 m
            let s = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
            return "≈ \(s) m"
        }
        return "≈ \(Int(m.rounded())) m"
    }
}
