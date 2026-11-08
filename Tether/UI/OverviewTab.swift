import SwiftUI
import TetherCore

/// The one screen most people need: is Tether on, which devices, how far before locking.
struct OverviewTab: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var newFeatures: NewFeatureStore
    @State private var picking: DeviceKind?
    @State private var showingAdvanced = false
    @State private var confirmingRemove: DeviceKind?

    private static let delays: [Double] = [3, 5, 8, 15]

    var body: some View {
        Form {
            Section {
                StatusCard()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                if settings.hasAnyDevice {
                    ForEach(settings.trackedKinds) { kind in
                        DeviceRow(kind: kind, change: { picking = kind }, remove: { remove(kind) })
                    }
                } else {
                    Text("Chưa chọn thiết bị nào. Tether cần ít nhất một iPhone, Apple Watch hoặc AirPods để biết bạn ở gần.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let next = DeviceKind.allCases.first(where: { settings.deviceID($0) == nil }) {
                    Button {
                        picking = next
                    } label: {
                        Label("Thêm thiết bị…", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                    .pointingHandCursor()
                }
                if settings.hasMultipleDevices {
                    Picker(selection: $settings.lockPolicy) {
                        ForEach(LockPolicy.allCases, id: \.self) { Text($0.shortTitle).tag($0) }
                    } label: {
                        FeatureLabel("Khoá khi", info: FeatureInfo.policy)
                    }
                    .pointingHandCursor()
                }
            } header: {
                HStack(spacing: 4) {
                    Text("Thiết bị")
                    AccuracyInfo()
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Picker(selection: presetBinding) {
                        ForEach(SettingsStore.DistancePreset.allCases) { Text($0.title).tag(Optional($0)) }
                        if settings.distancePreset == nil { Text("Tuỳ chỉnh").tag(SettingsStore.DistancePreset?.none) }
                    } label: {
                        FeatureLabel("Khoảng cách", info: FeatureInfo.distance, new: .distancePresets)
                    }
                    .pickerStyle(.segmented)
                    .pointingHandCursor()
                    Text("Mac khoá khi bạn đi xa hơn khoảng \(DistanceEstimate.text(rssi: settings.farThreshold).replacingOccurrences(of: "≈ ", with: "")).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Picker(selection: delayBinding) {
                        ForEach(Self.delays, id: \.self) { Text("\(Int($0)) giây").tag($0) }
                        if !Self.delays.contains(settings.lockDelay) {
                            Text("\(Int(settings.lockDelay)) giây").tag(settings.lockDelay)
                        }
                    } label: {
                        FeatureLabel("Chờ trước khi khoá", info: FeatureInfo.delay)
                    }
                    .pickerStyle(.segmented)
                    .pointingHandCursor()
                }
                HStack {
                    Button("Đo theo phòng của bạn…") { OnboardingWindow.shared.show() }
                        .pointingHandCursor()
                    Spacer()
                    Button("Nâng cao…") { showingAdvanced = true }
                        .buttonStyle(.borderless)
                        .pointingHandCursor()
                }
            } header: {
                Text("Khi nào khoá")
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.farThreshold) { _ in newFeatures.markSeen(.distancePresets) }
        .onChange(of: settings.lockDelay) { _ in newFeatures.markSeen(.distancePresets) }
        .sheet(item: $picking) { kind in
            DevicePickerSheet(initialKind: kind)
                .environmentObject(model)
                .environmentObject(settings)
        }
        .confirmationDialog(
            "Bỏ thiết bị cuối cùng?",
            isPresented: Binding(get: { confirmingRemove != nil }, set: { if !$0 { confirmingRemove = nil } }),
            presenting: confirmingRemove
        ) { kind in
            Button("Bỏ \(settings.deviceName(kind) ?? kind.title)", role: .destructive) { model.forget(kind) }
            Button("Huỷ", role: .cancel) {}
        } message: { _ in
            Text("Không còn thiết bị nào thì Tether không thể biết bạn ở gần, nên sẽ không tự khoá Mac.")
        }
        .sheet(isPresented: $showingAdvanced) {
            VStack(spacing: 0) {
                AdvancedDistanceView()
                    .environmentObject(model)
                    .environmentObject(settings)
                    .environmentObject(model.lockHistory)
                Divider()
                HStack {
                    Spacer()
                    Button("Xong") { showingAdvanced = false }
                        .keyboardShortcut(.defaultAction)
                        .pointingHandCursor()
                }
                .padding(12)
            }
            .frame(width: 600, height: 730)
        }
    }

    /// Removing the last device turns protection off, so that one asks first.
    private func remove(_ kind: DeviceKind) {
        if settings.trackedKinds.count <= 1 {
            confirmingRemove = kind
        } else {
            model.forget(kind)
        }
    }

    private var presetBinding: Binding<SettingsStore.DistancePreset?> {
        Binding(
            get: { settings.distancePreset },
            set: { if let p = $0 { settings.apply(p) } })
    }

    private var delayBinding: Binding<Double> {
        Binding(get: { settings.lockDelay }, set: { settings.lockDelay = $0 })
    }
}

/// One tracked device: name, live distance, and a button to change it.
private struct DeviceRow: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    let kind: DeviceKind
    let change: () -> Void
    let remove: () -> Void

    var body: some View {
        let rssi = model.deviceRSSI[kind]
        HStack(spacing: 10) {
            Image(systemName: kind.symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(settings.deviceName(kind) ?? kind.title)
                Text(rssi.map { DistanceEstimate.text(rssi: $0) } ?? "Chưa nghe thấy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            SignalBarsView(rssi: rssi)
            Button("Đổi…", action: change)
                .pointingHandCursor()
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .pointingHandCursor()
            .help("Bỏ thiết bị này")
            .accessibilityLabel("Bỏ \(settings.deviceName(kind) ?? kind.title)")
        }
    }
}

/// Pick (or forget) the device used for one kind.
struct DevicePickerSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind: DeviceKind

    init(initialKind: DeviceKind) {
        _kind = State(initialValue: initialKind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chọn thiết bị").font(.title2.bold())
            Picker("Loại", selection: $kind) {
                ForEach(DeviceKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .pointingHandCursor()
            Text("Đưa \(kind.title) sát Mac rồi bấm vào thiết bị có sóng mạnh nhất. Không cần cài gì lên \(kind.title).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DeviceListView(pickingFor: kind)
            HStack {
                if settings.deviceID(kind) != nil {
                    Button("Bỏ \(kind.title) này", role: .destructive) { model.forget(kind) }
                        .pointingHandCursor()
                }
                Spacer()
                Button("Xong") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .pointingHandCursor()
            }
        }
        .padding(20)
        .frame(width: 540, height: 520)
        .onAppear { model.setVisible(.settingsDevices, true) }
        .onDisappear { model.setVisible(.settingsDevices, false) }
    }
}

extension LockPolicy {
    /// Short label for the Overview picker.
    var shortTitle: String {
        switch self {
        case .allAway: return "Tất cả đều đi xa"
        case .anyAway: return "Một thiết bị bất kỳ đi xa"
        }
    }
}
