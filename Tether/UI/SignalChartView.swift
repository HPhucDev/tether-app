import AppKit
import Charts
import SwiftUI
import TetherCore

/// 5-minute signal chart:
/// - green / amber / red zones (back · in between · locks)
/// - draggable lock (red) and return (green) threshold lines
/// - each lock drawn as a dotted line with an orange band for the wait that led to it
struct SignalChartView: View {
    let samples: [DeviceKind: [RSSISample]]
    let events: [LockEvent]
    let lockDelay: TimeInterval
    let signalTimeout: TimeInterval
    @Binding var far: Double
    @Binding var near: Double
    var window: TimeInterval = 300

    private enum Line { case far, near }
    @State private var dragging: Line?

    private static let yMin: Double = -100
    private static let yMax: Double = -30

    var body: some View {
        let end = Date()
        let start = end.addingTimeInterval(-window)
        let visibleEvents = events.filter { $0.date >= start && $0.date <= end }

        Chart {
            // Zones
            RectangleMark(xStart: .value("t", start), xEnd: .value("t", end),
                          yStart: .value("dBm", Self.yMin), yEnd: .value("dBm", far))
                .foregroundStyle(Color.red.opacity(0.10))
            RectangleMark(xStart: .value("t", start), xEnd: .value("t", end),
                          yStart: .value("dBm", far), yEnd: .value("dBm", near))
                .foregroundStyle(Color.orange.opacity(0.06))
            RectangleMark(xStart: .value("t", start), xEnd: .value("t", end),
                          yStart: .value("dBm", near), yEnd: .value("dBm", Self.yMax))
                .foregroundStyle(Color.green.opacity(0.08))

            // Locks: orange wait window + dotted line
            ForEach(visibleEvents) { e in
                let wait = lockDelay + (e.reason == .signalLost ? signalTimeout : 0)
                let waitStart = max(start, e.date.addingTimeInterval(-wait))
                if e.reason != .test {
                    RectangleMark(xStart: .value("t", waitStart), xEnd: .value("t", e.date),
                                  yStart: .value("dBm", Self.yMin), yEnd: .value("dBm", Self.yMax))
                        .foregroundStyle(Color.orange.opacity(0.22))
                }
                RuleMark(x: .value("t", e.date))
                    .foregroundStyle(Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .annotation(position: .top, spacing: 2) {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.red)
                    }
            }

            // Signal lines
            ForEach(DeviceKind.allCases) { kind in
                ForEach(samples[kind] ?? []) { s in
                    LineMark(x: .value("t", s.date), y: .value("dBm", max(Self.yMin, min(Self.yMax, s.rssi))),
                             series: .value("Thiết bị", kind.title))
                        .foregroundStyle(by: .value("Thiết bị", kind.title))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 1.6))
                }
            }

            // Thresholds (draggable)
            RuleMark(y: .value("Mức khoá", far))
                .foregroundStyle(Color.red)
                .lineStyle(StrokeStyle(lineWidth: dragging == .far ? 3 : 2))
                .annotation(position: .bottom, alignment: .trailing, spacing: 2) {
                    tag("Khoá · \(DistanceEstimate.text(rssi: far))", color: .red)
                }
            RuleMark(y: .value("Mức quay lại", near))
                .foregroundStyle(Color.green)
                .lineStyle(StrokeStyle(lineWidth: dragging == .near ? 3 : 2))
                .annotation(position: .top, alignment: .trailing, spacing: 2) {
                    tag("Quay lại · \(DistanceEstimate.text(rssi: near))", color: .green)
                }
        }
        .chartForegroundStyleScale(domain: shownKinds.map(\.title), range: shownKinds.map(Self.color))
        .chartLegend(position: .top, alignment: .leading)
        .chartXScale(domain: start...end)
        .chartYScale(domain: Self.yMin...Self.yMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [-90, -75, -60, -45]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let d = value.as(Double.self) { Text(DistanceEstimate.text(rssi: d)) }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(proxy: proxy, geo: geo))
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let p):
                            if line(near: p.y - geo[proxy.plotAreaFrame].origin.y, proxy: proxy) != nil {
                                NSCursor.resizeUpDown.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        case .ended:
                            NSCursor.arrow.set()
                        }
                    }
            }
        }
        .overlay {
            if samples.values.allSatisfy(\.isEmpty) {
                Text("Chưa có dữ liệu sóng")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    /// Legend only lists devices that actually have data.
    private var shownKinds: [DeviceKind] {
        let kinds = DeviceKind.allCases.filter { !(samples[$0] ?? []).isEmpty }
        return kinds.isEmpty ? [.iPhone] : kinds
    }

    private static func color(_ kind: DeviceKind) -> Color {
        switch kind {
        case .iPhone: return .accentColor
        case .watch: return .purple
        case .other: return .teal
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.background.opacity(0.8), in: Capsule())
    }

    /// Which threshold line (if any) is within grabbing distance of `y` (plot-area coordinates).
    private func line(near y: CGFloat, proxy: ChartProxy) -> Line? {
        guard let fy = proxy.position(forY: far), let ny = proxy.position(forY: near) else { return nil }
        let df = abs(fy - y), dn = abs(ny - y)
        guard min(df, dn) <= 10 else { return nil }
        return df <= dn ? .far : .near
    }

    private func dragGesture(proxy: ChartProxy, geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let y = g.location.y - geo[proxy.plotAreaFrame].origin.y
                if dragging == nil {
                    // Only start a drag when grabbing a line, so the chart can still be clicked freely.
                    guard g.translation == .zero, let l = line(near: y, proxy: proxy) else { return }
                    dragging = l
                }
                guard let v: Double = proxy.value(atY: y) else { return }
                let clamped = min(-40, max(Self.yMin, v.rounded()))
                switch dragging {
                case .far?: far = clamped
                case .near?: near = clamped
                case nil: break
                }
            }
            .onEnded { _ in dragging = nil }
    }
}
