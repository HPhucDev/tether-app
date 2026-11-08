import Charts
import SwiftUI
import TetherCore

/// Desk time, break reminders and recent locks. Everything here stays on this Mac.
struct StatsTab: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var history: LockHistory
    @EnvironmentObject private var desk: DeskTimeStore
    @EnvironmentObject private var newFeatures: NewFeatureStore
    @State private var confirmClear = false
    @State private var showingAllLocks = false

    static let breakOptions = [30, 45, 60, 90]
    /// Locks shown inline; the rest open in a sheet so the tab never scrolls.
    static let recentCount = 3

    /// Any number of minutes, kept within 5…240.
    private var customMinutes: Binding<Int> {
        Binding(get: { settings.breakMinutes }, set: { settings.breakMinutes = min(max($0, 5), 240) })
    }

    var body: some View {
        let days = desk.lastDays(7)
        let today = days.last?.seconds ?? 0
        let average = days.map(\.seconds).reduce(0, +) / Double(max(days.count, 1))

        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    BigNumber(title: "Hôm nay ở bàn", value: DurationText.short(today))
                    Spacer()
                    BigNumber(title: "Trung bình 7 ngày", value: DurationText.short(average))
                }
                Chart(days, id: \.day) { item in
                    BarMark(
                        x: .value("Ngày", item.day, unit: .day),
                        y: .value("Giờ", item.seconds / 3600))
                        .foregroundStyle(Calendar.current.isDateInToday(item.day) ? Color.accentColor : Color.accentColor.opacity(0.45))
                        .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel { if let h = value.as(Double.self) { Text("\(Int(h))g") } }
                    }
                }
                .frame(height: 110)
                .overlay {
                    if days.allSatisfy({ $0.seconds < 60 }) {
                        Text("Chưa có số liệu. Tether bắt đầu đếm khi thiết bị của bạn ở gần.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            } header: {
                FeatureLabel("Thời gian ngồi bàn", info: FeatureInfo.deskTime, new: .deskTime)
            }

            Section {
                Toggle(isOn: $settings.breakReminder) {
                    FeatureLabel("Nhắc đứng dậy khi ngồi lâu", hint: "Gửi thông báo khi bạn ngồi liền quá lâu.",
                                 info: FeatureInfo.breakReminder, new: .breakReminder)
                }
                .pointingHandCursor()
                .onChange(of: settings.breakReminder) {
                    newFeatures.markSeen(.breakReminder)
                    if $0 { Notifier.requestAuthorization() }
                }
                if settings.breakReminder {
                    LabeledContent("Nhắc sau") {
                        HStack(spacing: 8) {
                            Picker("Nhắc sau", selection: $settings.breakMinutes) {
                                ForEach(Self.breakOptions, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .fixedSize()
                            .pointingHandCursor()
                            TextField("Số phút", value: customMinutes, format: .number)
                                .labelsHidden()
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 52)
                                .help("Gõ số phút bất kỳ, từ 5 đến 240.")
                            Text("phút")
                        }
                    }
                    let sitting = desk.deskTime.sittingDuration(at: Date())
                    if sitting >= 60 {
                        Text("Bạn đã ngồi liền \(DurationText.short(sitting)).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Nhắc nghỉ")
            }

            Section {
                if history.events.isEmpty {
                    Text("Chưa có lần khoá nào. Bấm “Khoá thử” trên thanh menu để thử.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history.events.prefix(Self.recentCount)) { LockEventRow(event: $0) }
                    if history.events.count > Self.recentCount {
                        Button("Xem tất cả \(history.events.count) lần…") { showingAllLocks = true }
                            .buttonStyle(.borderless)
                            .pointingHandCursor()
                    }
                }
            } header: {
                HStack {
                    Text("Lần khoá gần đây")
                    Spacer()
                    Button("Xoá") { confirmClear = true }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .pointingHandCursor()
                        .disabled(history.events.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.breakMinutes) { _ in newFeatures.markSeen(.breakReminder) }
        // Seeing the numbers once is enough for this one.
        .onDisappear { newFeatures.markSeen(.deskTime) }
        .sheet(isPresented: $showingAllLocks) {
            VStack(spacing: 0) {
                List(history.events) { LockEventRow(event: $0) }
                Divider()
                HStack {
                    Text("\(history.events.count) lần khoá gần nhất, chỉ lưu trên Mac này.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Xong") { showingAllLocks = false }
                        .keyboardShortcut(.defaultAction)
                        .pointingHandCursor()
                }
                .padding(12)
            }
            .frame(width: 480, height: 460)
        }
        .confirmationDialog("Xoá lịch sử khoá?", isPresented: $confirmClear) {
            Button("Xoá", role: .destructive) { history.clear() }
        }
    }
}

private struct BigNumber: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
        }
    }
}

private struct LockEventRow: View {
    let event: LockEvent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.reason.symbol)
                .frame(width: 20)
                .foregroundStyle(event.reason == .test ? Color.secondary : Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.reason.title)
                if let note {
                    Text(note).font(.caption).foregroundStyle(event.method == ScreenLocker.Method.failed.rawValue ? .red : .secondary)
                }
            }
            Spacer()
            Text(event.date.formatted(.relative(presentation: .named)))
                .font(.callout)
                .foregroundStyle(.secondary)
                .help(event.date.formatted(date: .abbreviated, time: .standard))
        }
    }

    private var note: String? {
        if event.method == ScreenLocker.Method.failed.rawValue { return "Không khoá được" }
        if event.method == ScreenLocker.Method.screenSaver.rawValue { return "Khoá bằng trình bảo vệ màn hình" }
        return nil
    }
}
