import SwiftUI
import TetherCore

/// Daily-use popover: one status card, one line per device, a compact action bar.
struct MenuPopoverView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusCard()

            if settings.hasAnyDevice {
                VStack(spacing: 10) {
                    ForEach(settings.trackedKinds) { kind in
                        DeviceLine(kind: kind)
                    }
                }
                .padding(.horizontal, 4)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chưa chọn thiết bị nào để theo dõi.")
                        .foregroundStyle(.secondary)
                    OpenSettingsButton(title: "Chọn thiết bị…")
                }
                .padding(.horizontal, 4)
            }

            DeskTimeLine(store: model.deskTime)
                .padding(.horizontal, 4)

            Divider()

            ActionBar()
        }
        .padding(12)
        .frame(width: 300)
        .onAppear { model.setVisible(.popover, true) }
        .onDisappear { model.setVisible(.popover, false) }
    }
}

// MARK: - Status card

struct StatusCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        let status = model.status
        let offSchedule = model.isOffSchedule
        let forgotten = model.isDeviceForgotten
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: offSchedule ? "moon.zzz.fill" : forgotten ? "pause.circle.fill" : status.cardSymbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(forgotten ? Color.orange : offSchedule || status.color == .secondary ? Color.secondary : status.color)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(model.statusTitle).font(.headline)
                    InfoButton(title: model.statusTitle, text: model.statusExplanation)
                }
                Text(offSchedule ? (model.nextScheduledStartText ?? "Ngoài giờ trong lịch, Tether không khoá Mac.")
                     : forgotten ? "\(model.forgottenNames) đang bị bỏ quên ở xa. Tether tự theo dõi lại khi thiết bị quay về gần."
                     : subtitle(status))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Toggle("Bật Tether", isOn: $settings.isEnabled)
                .pointingHandCursor()
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((offSchedule ? Color.gray : forgotten ? Color.orange : tint(status)).opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder((offSchedule ? Color.gray : forgotten ? Color.orange : tint(status)).opacity(0.25))
        )
        .animation(.easeInOut(duration: 0.25), value: status)
        .animation(.easeInOut(duration: 0.25), value: offSchedule)
        .animation(.easeInOut(duration: 0.25), value: forgotten)
    }

    private func tint(_ s: ProximityStatus) -> Color {
        s.color == .secondary ? Color.gray : s.color
    }

    private func subtitle(_ s: ProximityStatus) -> String {
        switch s {
        case .near:
            return "Mac khoá khi bạn đi xa hơn \(DistanceEstimate.text(rssi: settings.farThreshold)) trong \(Int(settings.lockDelay)) giây."
        case .leaving(let left):
            return "Bạn đang rời đi. Mac khoá sau \(left) giây."
        case .signalLost(let left):
            return "Không nghe thấy thiết bị. Mac khoá sau \(left) giây."
        case .paused(let until):
            return "Không khoá cho tới \(until.formatted(date: .omitted, time: .shortened))."
        case .disabled:
            return "Bật công tắc để bảo vệ Mac."
        case .searching:
            return settings.hasAnyDevice
                ? "Đưa thiết bị lại gần Mac để bắt đầu bảo vệ."
                : "Chọn một thiết bị để bắt đầu."
        case .away:
            return "Đang chờ thiết bị quay lại gần."
        case .bluetoothOff:
            return "Bật Bluetooth để Tether hoạt động."
        }
    }
}

// MARK: - Desk time

private struct DeskTimeLine: View {
    @ObservedObject var store: DeskTimeStore

    var body: some View {
        let today = store.today()
        if today >= 60 {
            Label("Hôm nay ở bàn \(DurationText.short(today))", systemImage: "chair")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Device line

private struct DeviceLine: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    let kind: DeviceKind

    var body: some View {
        let rssi = model.deviceRSSI[kind]
        HStack(spacing: 10) {
            Image(systemName: kind.symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(settings.deviceName(kind) ?? kind.title)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let rssi, model.connection(kind) == .listening {
                SignalBarsView(rssi: rssi)
                Text(DistanceEstimate.text(rssi: rssi))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
            } else {
                Text("Chưa nghe thấy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Action bar

private struct ActionBar: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var newFeatures: NewFeatureStore

    var body: some View {
        HStack(spacing: 8) {
            if model.pausedUntil != nil {
                Button {
                    model.resume()
                } label: {
                    Label("Tiếp tục", systemImage: "play.fill")
                }
                .pointingHandCursor()
            } else {
                Menu {
                    Button("15 phút") { model.pause(for: 15 * 60) }
                    Button("30 phút") { model.pause(for: 30 * 60) }
                    Button("1 giờ") { model.pause(for: 60 * 60) }
                    Button("2 giờ") { model.pause(for: 2 * 60 * 60) }
                    Divider()
                    Button("Tới 7 giờ sáng mai") { model.pause(for: Self.untilTomorrowMorning()) }
                } label: {
                    Label("Tạm dừng", systemImage: "pause.fill")
                }
                .menuStyle(.borderedButton)
                .fixedSize()
                .pointingHandCursor()
            }

            Spacer()

            IconButton(symbol: "lock", help: "Khoá thử ngay") {
                model.testLock()
            }
            IconButton(symbol: "gearshape", help: newFeatures.hasUnseen ? "Cài đặt (⌘,) · có tính năng mới" : "Cài đặt (⌘,)") {
                SettingsWindow.shared.show(tab: .overview)
            }
            .overlay(alignment: .topTrailing) {
                if newFeatures.hasUnseen {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6).offset(x: 2, y: -2)
                }
            }
            IconButton(symbol: "power", help: "Thoát Tether") {
                NSApp.terminate(nil)
            }
        }
        .labelStyle(.titleAndIcon)
    }

    static func untilTomorrowMorning(now: Date = Date()) -> TimeInterval {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
        let morning = cal.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        return morning.timeIntervalSince(now)
    }
}

private struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.borderless)
        .pointingHandCursor()
        .help(help)
        .accessibilityLabel(help)
    }
}
