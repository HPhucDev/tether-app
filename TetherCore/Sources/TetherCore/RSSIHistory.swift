import Foundation

public struct RSSISample: Identifiable, Equatable, Sendable {
    public let date: Date
    public let rssi: Double
    public var id: Date { date }

    public init(date: Date, rssi: Double) {
        self.date = date
        self.rssi = rssi
    }
}

/// Fixed-capacity ring buffer of recent RSSI samples (default: last 60 s).
public struct RSSIHistory: Sendable {
    public let window: TimeInterval
    public let capacity: Int
    private var storage: [RSSISample?]
    private var head = 0  // next write index
    public private(set) var count = 0

    public init(window: TimeInterval = 60, capacity: Int = 240) {
        precondition(capacity > 0)
        self.window = window
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    public mutating func append(_ sample: RSSISample) {
        storage[head] = sample
        head = (head + 1) % capacity
        count = min(count + 1, capacity)
    }

    public mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        head = 0
        count = 0
    }

    /// Samples within `window` seconds of `now`, oldest first.
    public func samples(asOf now: Date) -> [RSSISample] {
        let cutoff = now.addingTimeInterval(-window)
        var result: [RSSISample] = []
        result.reserveCapacity(count)
        let start = (head - count + capacity) % capacity
        for i in 0..<count {
            if let s = storage[(start + i) % capacity], s.date >= cutoff, s.date <= now {
                result.append(s)
            }
        }
        return result
    }
}
