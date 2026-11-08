import SwiftUI
import TetherCore

extension ProximityStatus {
    var symbolName: String {
        switch self {
        case .near: return "link"
        case .leaving: return "figure.walk"
        case .signalLost, .bluetoothOff: return "exclamationmark.triangle"
        case .paused: return "pause.circle"
        case .disabled: return "circle.slash"
        case .searching: return "magnifyingglass"
        case .away: return "lock"
        }
    }

    var title: String {
        switch self {
        case .near: return "Đang ở gần"
        case .leaving(let s): return "Rời đi, khoá sau \(s)s"
        case .signalLost(let s): return "Mất kết nối, khoá sau \(s)s"
        case .bluetoothOff: return "Bluetooth đang tắt"
        case .paused(let until): return "Đang tạm dừng đến \(until.formatted(date: .omitted, time: .shortened))"
        case .disabled: return "Tether đang tắt"
        case .searching: return "Đang chờ thiết bị ở gần"
        case .away: return "Đã khoá, chờ thiết bị quay lại"
        }
    }

    var color: Color {
        switch self {
        case .near: return .green
        case .leaving: return .orange
        case .signalLost, .bluetoothOff: return .red
        case .paused, .disabled, .searching, .away: return .secondary
        }
    }
}

extension ConnectionState {
    var title: String {
        switch self {
        case .idle: return "Chưa chọn thiết bị"
        case .listening: return "Đang nghe tín hiệu"
        case .notHeard: return "Chưa nghe thấy tín hiệu"
        }
    }
}

struct SignalBarsView: View {
    let rssi: Double?

    var body: some View {
        let bars = SignalStrength.bars(rssi: rssi)
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < bars ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 4, height: CGFloat(5 + i * 3))
            }
        }
        .accessibilityLabel("\(bars) trên 4 vạch sóng")
    }
}

struct RSSIText: View {
    let rssi: Double?
    var body: some View {
        Text(rssi.map { "\(DistanceEstimate.text(rssi: $0)) · \(Int($0.rounded())) dBm" } ?? "—")
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

/// ⓘ icon with a tooltip explaining that passive Bluetooth proximity is approximate.
struct AccuracyInfo: View {
    static let text = """
    Khoảng cách (số mét) chỉ là ước lượng, không chính xác.
    Tether đo độ mạnh sóng Bluetooth mà iPhone/Apple Watch tự phát ra. Sóng bị ảnh hưởng bởi tường, người, túi quần, ốp lưng…
    Khi iPhone khoá màn hình hoặc Watch nằm yên, chúng phát tín hiệu thưa hơn nên Tether có thể báo xa hoặc mất tín hiệu nhầm.
    Hãy chọn lại khoảng cách khoá hoặc đo lại theo phòng của bạn trong tab Tổng quan.
    """

    @State private var isShown = false

    var body: some View {
        // Hover tooltips are unreliable in section headers and in the menu bar popover,
        // so clicking opens a popover with the explanation.
        Button {
            isShown.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .help(Self.text)
        .accessibilityLabel("Giải thích độ chính xác")
        .popover(isPresented: $isShown, arrowEdge: .bottom) {
            Text(Self.text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 300, alignment: .leading)
                .padding(14)
        }
    }
}

extension ProximityStatus {
    /// Larger, friendlier wording for the popover's status card.
    var cardTitle: String {
        switch self {
        case .near: return "Đang bảo vệ"
        case .leaving: return "Đang rời đi"
        case .signalLost: return "Mất tín hiệu"
        case .paused: return "Đang tạm dừng"
        case .disabled: return "Tether đang tắt"
        case .searching: return "Chờ thiết bị"
        case .away: return "Đã khoá"
        case .bluetoothOff: return "Bluetooth đang tắt"
        }
    }

    var cardSymbol: String {
        switch self {
        case .near: return "checkmark.shield.fill"
        case .leaving: return "figure.walk"
        case .signalLost, .bluetoothOff: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle.fill"
        case .disabled: return "shield.slash"
        case .searching: return "dot.radiowaves.left.and.right"
        case .away: return "lock.fill"
        }
    }
}

extension AppModel {
    /// Card title, aware of the schedule (Tether on, but resting outside its hours).
    var statusTitle: String { isOffSchedule ? "Ngoài lịch hoạt động" : status.cardTitle }

    var menuBarSymbol: String { isOffSchedule ? "moon.zzz" : status.symbolName }

    /// When the schedule turns protection back on, e.g. "Bảo vệ lại lúc 08:00 thứ Hai".
    var nextScheduledStartText: String? {
        guard isOffSchedule, let next = settings.schedule.nextStart(after: Date()) else { return nil }
        let time = next.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(next) { return "Bảo vệ lại lúc \(time) hôm nay." }
        if Calendar.current.isDateInTomorrow(next) { return "Bảo vệ lại lúc \(time) ngày mai." }
        return "Bảo vệ lại lúc \(time), \(next.formatted(.dateTime.weekday(.wide)))."
    }
}
