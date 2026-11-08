import SwiftUI
import TetherCore

/// When and why Tether locked the Mac. Stored only on this Mac.
struct HistoryTab: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var history: LockHistory
    @State private var confirmClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(history.events.count) lần khoá gần nhất")
                    .font(.headline)
                Spacer()
                Button("Xoá lịch sử", role: .destructive) { confirmClear = true }
                    .pointingHandCursor()
                    .disabled(history.events.isEmpty)
            }

            List(history.events) { event in
                LockEventRow(event: event)
            }
            .overlay {
                if history.events.isEmpty {
                    Text("Chưa có lần khoá nào.\nBấm “Khoá thử” trên thanh menu để thử.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }

            Label("Lịch sử chỉ lưu trên Mac này (tối đa \(LockHistory.limit) lần), không gửi đi đâu.", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .confirmationDialog("Xoá toàn bộ lịch sử khoá?", isPresented: $confirmClear) {
            Button("Xoá", role: .destructive) { history.clear() }
        }
    }
}

private struct LockEventRow: View {
    let event: LockEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: event.reason.symbol)
                .frame(width: 22)
                .foregroundStyle(event.reason == .test ? Color.secondary : Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.reason.title).bold()
                    Spacer()
                    Text(event.date.formatted(date: .abbreviated, time: .standard))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                ForEach(event.readings, id: \.kind) { r in
                    HStack(spacing: 6) {
                        Image(systemName: DeviceKind(rawValue: r.kind)?.symbol ?? "dot.radiowaves.right")
                            .frame(width: 16)
                        Text(r.name ?? DeviceKind(rawValue: r.kind)?.title ?? r.kind)
                        Spacer()
                        Text(r.rssi.map(DistanceText.describe) ?? "Không có tín hiệu")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if event.method == ScreenLocker.Method.screenSaver.rawValue {
                    Text("Khoá bằng trình bảo vệ màn hình")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if event.method == ScreenLocker.Method.failed.rawValue {
                    Text("Không khoá được")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
