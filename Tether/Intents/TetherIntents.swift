import AppIntents
import Foundation

// Actions Tether offers to the Shortcuts app (and Spotlight / Siri on macOS 13+).
// They run inside Tether, so nothing extra is needed from the App Sandbox.

@MainActor
private func model() -> AppModel {
    let m = AppModel.shared
    m.start()   // no-op when already running; covers Shortcuts launching Tether
    return m
}

struct PauseTetherIntent: AppIntent {
    static var title: LocalizedStringResource = "Tạm dừng Tether"
    static var description = IntentDescription("Tether không khoá Mac trong khoảng thời gian bạn chọn.")

    @Parameter(title: "Số phút", default: 60, inclusiveRange: (1, 1440))
    var minutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Tạm dừng Tether trong \(\.$minutes) phút")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        model().pause(for: TimeInterval(minutes * 60))
        return .result(dialog: "Tether tạm dừng \(minutes) phút.")
    }
}

struct ResumeTetherIntent: AppIntent {
    static var title: LocalizedStringResource = "Tiếp tục Tether"
    static var description = IntentDescription("Bỏ tạm dừng, Tether bảo vệ Mac trở lại.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        model().resume()
        return .result(dialog: "Tether đã bảo vệ trở lại.")
    }
}

struct SetTetherEnabledIntent: AppIntent {
    static var title: LocalizedStringResource = "Bật hoặc tắt Tether"
    static var description = IntentDescription("Bật hay tắt hẳn việc tự khoá Mac.")

    @Parameter(title: "Bật", default: true)
    var enabled: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Đặt Tether thành \(\.$enabled)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        model().settings.isEnabled = enabled
        return .result(dialog: enabled ? "Đã bật Tether." : "Đã tắt Tether.")
    }
}

struct LockMacIntent: AppIntent {
    static var title: LocalizedStringResource = "Khoá Mac ngay"
    static var description = IntentDescription("Khoá màn hình Mac ngay lập tức.")

    @MainActor
    func perform() async throws -> some IntentResult {
        model().lockFromShortcut()
        return .result()
    }
}

struct TetherStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Trạng thái Tether"
    static var description = IntentDescription("Cho biết Tether có đang bảo vệ Mac không.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let m = model()
        let protecting: Bool
        if case .near = m.status { protecting = true } else { protecting = false }
        return .result(value: protecting, dialog: "\(m.statusTitle)")
    }
}

struct TetherShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PauseTetherIntent(), phrases: ["Tạm dừng \(.applicationName)", "Pause \(.applicationName)"])
        AppShortcut(intent: ResumeTetherIntent(), phrases: ["Tiếp tục \(.applicationName)", "Resume \(.applicationName)"])
        AppShortcut(intent: LockMacIntent(), phrases: ["Khoá Mac bằng \(.applicationName)", "Lock my Mac with \(.applicationName)"])
        AppShortcut(intent: TetherStatusIntent(), phrases: ["Trạng thái \(.applicationName)", "\(.applicationName) status"])
    }
}
