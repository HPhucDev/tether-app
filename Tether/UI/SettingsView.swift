import AppKit
import Charts
import SwiftUI
import TetherCore

// MARK: - Device picking

struct DeviceListView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    let pickingFor: DeviceKind
    @State private var showAll = false

    private var visibleDevices: [DiscoveredDevice] {
        model.devices.filter { showAll || $0.isMine || assignedKind($0) != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            list
            Toggle("Hiện tất cả thiết bị xung quanh", isOn: $showAll)
                .pointingHandCursor()
                .font(.caption)
                .help("Mặc định chỉ hiện thiết bị đăng nhập cùng Apple ID với Mac hoặc đã ghép đôi Bluetooth.")
        }
    }

    private var list: some View {
        List(visibleDevices) { device in
            Button {
                model.select(device, as: pickingFor)
            } label: {
                HStack {
                    Image(systemName: device.guessedKind?.symbol ?? "dot.radiowaves.right")
                        .frame(width: 20)
                    Text(device.displayName)
                    Spacer()
                    SignalBarsView(rssi: Double(device.rssi))
                    RSSIText(rssi: Double(device.rssi)).frame(width: 120, alignment: .trailing)
                    Image(systemName: assignedKind(device)?.symbol ?? "checkmark")
                        .frame(width: 16)
                        .opacity(assignedKind(device) == nil ? 0 : 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .opacity(device.guessedKind == nil || device.guessedKind == pickingFor ? 1 : 0.5)
        }
        .overlay {
            if visibleDevices.isEmpty {
                Text(emptyText)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .frame(minHeight: 160)
    }

    private var emptyText: String {
        if model.power != .poweredOn { return "Bluetooth chưa sẵn sàng" }
        if model.devices.isEmpty || showAll { return "Đang quét…" }
        return "Chưa thấy thiết bị nào của bạn.\nThiết bị cần đăng nhập cùng Apple ID với Mac, hoặc đã ghép đôi Bluetooth."
    }

    private func assignedKind(_ device: DiscoveredDevice) -> DeviceKind? {
        DeviceKind.allCases.first { settings.deviceID($0) == device.id }
    }
}

extension LockPolicy {
    var title: String {
        switch self {
        case .allAway: return "Tất cả đều đi xa"
        case .anyAway: return "Bất kỳ thiết bị nào đi xa"
        }
    }

    var explanation: String {
        switch self {
        case .allAway: return "Còn một thiết bị ở gần thì coi như bạn vẫn ngồi đó. Hợp khi bạn hay để iPhone trên bàn và đeo Watch."
        case .anyAway: return "Chặt hơn: chỉ cần một thiết bị đi xa là khoá. Thiết bị chưa từng ở gần (ví dụ AirPods đang trong hộp) sẽ được bỏ qua."
        }
    }
}

// MARK: - Advanced distance (sheet from Overview)

/// Signal chart and fine-grained thresholds, for people who want to tune by hand.
struct AdvancedDistanceView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var lockHistory: LockHistory

    private var farBinding: Binding<Double> {
        Binding(
            get: { settings.farThreshold },
            set: {
                settings.farThreshold = $0
                if settings.nearThreshold < $0 + 3 { settings.nearThreshold = $0 + 3 }
            })
    }

    private var nearBinding: Binding<Double> {
        Binding(
            get: { settings.nearThreshold },
            set: {
                settings.nearThreshold = $0
                if settings.farThreshold > $0 - 3 { settings.farThreshold = $0 - 3 }
            })
    }

    var body: some View {
        Form {
            Section {
                ForEach(settings.trackedKinds) { kind in
                    HStack {
                        Image(systemName: kind.symbol).frame(width: 20)
                        Text(settings.deviceName(kind) ?? kind.title)
                        Spacer()
                        SignalBarsView(rssi: model.deviceRSSI[kind])
                        Text(model.deviceRSSI[kind].map(DistanceText.describe) ?? "Chưa có tín hiệu")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                if !settings.hasAnyDevice {
                    Text("Chưa chọn thiết bị nào.").foregroundStyle(.secondary)
                }
                SignalChartView(
                    samples: model.historySamples,
                    events: lockHistory.events,
                    lockDelay: settings.lockDelay,
                    signalTimeout: settings.proximityConfiguration.signalTimeout,
                    far: farBinding,
                    near: nearBinding)
                    .frame(height: 190)
                    .padding(.vertical, 4)
                Text("Kéo đường đỏ (mức khoá) hoặc đường xanh (mức quay lại) để chỉnh. Mỗi lần khoá có dấu 🔒, vùng cam là khoảng thời gian chờ trước khi khoá.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                HStack(spacing: 4) {
                    Text("Sóng 5 phút gần nhất")
                    AccuracyInfo()
                }
            }

            Section("Khi nào khoá") {
                ThresholdSlider(
                    title: "Khoá khi thiết bị ra xa tới mức",
                    hint: "Kéo về phía Xa nếu Mac hay khoá nhầm khi bạn vẫn ngồi ở bàn. Số mét chỉ là ước lượng.",
                    value: farBinding)
                if settings.farThreshold >= -60 {
                    Label("Mức khoá chỉ \(DistanceEstimate.text(rssi: settings.farThreshold)): Mac có thể khoá cả khi bạn ngồi ngay cạnh.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                ThresholdSlider(
                    title: "Tính là đã quay lại khi gần tới mức",
                    hint: "Nên gần hơn mức khoá một chút, để Mac không khoá rồi lại coi là quay lại liên tục khi sóng chập chờn.",
                    value: nearBinding)
                HStack {
                    Text("Chờ trước khi khoá")
                    Slider(value: $settings.lockDelay, in: 1...30, step: 1)
                        .pointingHandCursor()
                    Text("\(Int(settings.lockDelay)) giây").monospacedDigit().frame(width: 60, alignment: .trailing)
                }
                .help("Bạn phải ở xa liên tục chừng này giây thì Mac mới khoá.")
                Button("Lấy vị trí hiện tại làm mức khoá") { model.calibrateFarHere() }
                    .pointingHandCursor()
                    .disabled(model.currentRSSI == nil)
                    .help("Mang thiết bị tới chỗ muốn Mac khoá (ví dụ cửa phòng) rồi bấm.")
            }
        }
        .formStyle(.grouped)
        .onAppear { model.setVisible(.settingsDistance, true) }
        .onDisappear { model.setVisible(.settingsDistance, false) }
    }
}

enum DistanceText {
    /// "≈ 4 m · Vừa · −72 dBm"
    static func describe(_ rssi: Double) -> String {
        "\(DistanceEstimate.text(rssi: rssi)) · \(DistanceLabel(rssi: rssi).rawValue) · \(Int(rssi.rounded())) dBm"
    }
}

struct ThresholdSlider: View {
    let title: String
    let hint: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                InfoButton(title: title, text: hint)
                Spacer()
                Text(DistanceText.describe(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: -100...(-40), step: 1) {
                EmptyView()
            } minimumValueLabel: {
                Text("Xa").font(.caption)
            } maximumValueLabel: {
                Text("Gần").font(.caption)
            }
            .pointingHandCursor()
        }
    }
}

// MARK: - General

struct GeneralTab: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Picker("Icon ở Dock", selection: $settings.dockIconMode) {
                ForEach(DockIconMode.allCases) { Text($0.title).tag($0) }
            }
            .pointingHandCursor()
            .help("Tether luôn có icon trên thanh menu. “Khi mở cửa sổ”: chỉ hiện ở Dock lúc đang mở Cài đặt hoặc Thiết lập.")
            Toggle("Mở cùng máy", isOn: $launchAtLogin)
                .pointingHandCursor()
                .onChange(of: launchAtLogin) { LoginItem.setEnabled($0) }
            Picker("Khi Bluetooth tắt", selection: $settings.bluetoothOffAction) {
                ForEach(BluetoothOffAction.allCases) { Text($0.title).tag($0) }
            }
            .pointingHandCursor()
            Toggle("Thông báo khi khoá", isOn: $settings.notifyOnLock)
                .pointingHandCursor()
                .onChange(of: settings.notifyOnLock) { if $0 { Notifier.requestAuthorization() } }

            Section("Mở khoá nhanh") {
                Text("Tether chỉ khoá, không tự mở khoá. Để mở nhanh, bật “Dùng Apple Watch để mở khoá” trong Cài đặt hệ thống › Touch ID & Mật khẩu.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Mở Touch ID & Mật khẩu…") { SystemSettings.openTouchIDAndPassword() }
                    .pointingHandCursor()
            }

            Section {
                LabeledContent {
                    Button("Xem lại…") { OnboardingWindow.shared.show() }
                        .pointingHandCursor()
                } label: {
                    Text("Hướng dẫn thiết lập")
                    Text("Chọn lại thiết bị và đo lại khoảng cách khoá, từng bước như lần đầu.")
                }
                LabeledContent {
                    Button("Đặt lại…", role: .destructive) { confirmingReset = true }
                        .pointingHandCursor()
                } label: {
                    Text("Đặt lại Tether")
                    Text("Quên thiết bị, đưa mọi cài đặt về mặc định và xoá lịch sử khoá.")
                }
            } header: {
                Text("Hướng dẫn & đặt lại")
            }
        }
        .formStyle(.grouped)
        .alert("Đặt lại Tether về mặc định?", isPresented: $confirmingReset) {
            Button("Đặt lại", role: .destructive) {
                model.resetToDefaults()
                launchAtLogin = false
                // No device is tracked any more: go pick one.
                SettingsWindow.shared.show(tab: .overview)
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Tether sẽ quên thiết bị đã chọn, đưa ngưỡng khoá và mọi tuỳ chỉnh về mặc định, tắt “Mở cùng máy” và xoá toàn bộ lịch sử khoá. Không thể hoàn tác.")
        }
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }
}
