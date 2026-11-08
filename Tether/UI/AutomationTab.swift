import SwiftUI
import TetherCore

/// When Tether protects, and what happens when you leave or come back.
struct AutomationTab: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var newFeatures: NewFeatureStore
    /// The user's shortcuts; nil while loading or when they can't be read (then a text field is shown).
    @State private var shortcutNames: [String]?
    @State private var loadedShortcuts = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.scheduleEnabled) {
                    FeatureLabel("Chỉ bảo vệ theo lịch", hint: "Ngoài giờ này Tether không khoá Mac.",
                                 info: FeatureInfo.schedule, new: .schedule)
                }
                .pointingHandCursor()
                if settings.scheduleEnabled {
                    LabeledContent("Ngày") { WeekdayPicker(selection: $settings.schedule.weekdays) }
                    DatePicker("Từ", selection: minuteBinding(\.startMinute), displayedComponents: .hourAndMinute)
                        .pointingHandCursor()
                    DatePicker("Đến", selection: minuteBinding(\.endMinute), displayedComponents: .hourAndMinute)
                        .pointingHandCursor()
                }
            } header: {
                Text("Lịch hoạt động")
            }

            Section {
                Toggle(isOn: $settings.wakeOnReturn) {
                    FeatureLabel("Bật sáng màn hình chờ sẵn", hint: "Tether không tự mở khoá.",
                                 info: FeatureInfo.wake, new: .wakeOnReturn)
                }
                .pointingHandCursor()
            } header: {
                Text("Khi bạn quay lại")
            }

            Section {
                ShortcutPicker(title: "Khi rời đi", selection: $settings.leaveShortcut, names: shortcutNames)
                ShortcutPicker(title: "Khi quay lại", selection: $settings.returnShortcut, names: shortcutNames)
                HStack {
                    Button("Làm mới danh sách") { Task { await loadShortcuts() } }
                        .buttonStyle(.borderless)
                        .pointingHandCursor()
                    Spacer()
                    Button("Mở app Phím tắt") { ShortcutRunner.openShortcutsApp() }
                        .pointingHandCursor()
                }
            } header: {
                FeatureLabel("Phím tắt", info: FeatureInfo.shortcuts, new: .shortcuts)
            }
        }
        .formStyle(.grouped)
        .task { if !loadedShortcuts { await loadShortcuts() } }
        .onChange(of: settings.scheduleEnabled) { _ in newFeatures.markSeen(.schedule) }
        .onChange(of: settings.schedule) { _ in newFeatures.markSeen(.schedule) }
        .onChange(of: settings.wakeOnReturn) { _ in newFeatures.markSeen(.wakeOnReturn) }
        .onChange(of: settings.leaveShortcut) { _ in newFeatures.markSeen(.shortcuts) }
        .onChange(of: settings.returnShortcut) { _ in newFeatures.markSeen(.shortcuts) }
    }

    private func loadShortcuts() async {
        shortcutNames = await ShortcutLibrary.names()
        loadedShortcuts = true
    }

    /// Edits a minutes-after-midnight field of the schedule through a time picker.
    private func minuteBinding(_ keyPath: WritableKeyPath<ActiveSchedule, Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(byAdding: .minute, value: settings.schedule[keyPath: keyPath],
                                      to: Calendar.current.startOfDay(for: Date())) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings.schedule[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
    }
}

/// A toggle/row label with a one-line explanation under it.
struct TitleAndHint: View {
    let title: String
    let hint: String

    init(_ title: String, _ hint: String) {
        self.title = title
        self.hint = hint
    }

    var body: some View {
        FeatureLabel(title, hint: hint)
    }
}

/// Mon … Sun chips (calendar weekdays 2…7, 1).
private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    private static let days: [(Int, String)] = [(2, "T2"), (3, "T3"), (4, "T4"), (5, "T5"), (6, "T6"), (7, "T7"), (1, "CN")]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Self.days, id: \.0) { day, label in
                let on = selection.contains(day)
                Button {
                    if on { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .frame(width: 30, height: 24)
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .background(on ? Color.accentColor : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .accessibilityLabel(label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Pick one of the user's shortcuts from a menu (or type its name if the list can't be read).
private struct ShortcutPicker: View {
    let title: String
    @Binding var selection: String
    let names: [String]?

    var body: some View {
        LabeledContent(title) {
            HStack {
                if let names {
                    Picker(title, selection: $selection) {
                        Text("Không chạy gì").tag("")
                        if !selection.isEmpty && !names.contains(selection) {
                            Text("\(selection) (không còn)").tag(selection)
                        }
                        if !names.isEmpty { Divider() }
                        ForEach(names, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .pointingHandCursor()
                } else {
                    TextField(title, text: $selection, prompt: Text("Tên phím tắt"))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 230)
                }
                Button("Thử") { ShortcutRunner.run(selection) }
                    .disabled(selection.trimmingCharacters(in: .whitespaces).isEmpty)
                    .pointingHandCursor()
            }
        }
    }
}
