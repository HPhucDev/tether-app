import AppKit
import SwiftUI
import TetherCore

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: SettingsStore
    let onFinish: () -> Void

    private enum Step: Int, CaseIterable { case permission, device, desk, away, done }
    private enum Measure: Equatable { case idle, countdown(Int), measuring, finished(Double), failed }

    @State private var step: Step = .permission
    @State private var pickingFor: DeviceKind = .iPhone

    /// Calibration measures the iPhone when one is chosen, otherwise the Watch.
    private var calibrationDeviceName: String { settings.deviceName(model.calibrationKind) ?? model.calibrationKind.title }
    @State private var deskMeasure: Measure = .idle
    @State private var awayMeasure: Measure = .idle
    @State private var result: (far: Double, near: Double)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
            Group {
                switch step {
                case .permission: permission
                case .device: device
                case .desk: desk
                case .away: away
                case .done: done
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .padding(24)
        .frame(width: 520, height: 520)
        .onAppear { model.setVisible(.onboarding, true) }
        .onDisappear { model.setVisible(.onboarding, false) }
    }

    // MARK: Steps

    private var permission: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chào mừng tới Tether").font(.largeTitle.bold())
            Text("Khi bạn mang iPhone hoặc Apple Watch đi xa, Mac sẽ tự khoá màn hình.")
            Text("Tether cần quyền Bluetooth để đo cường độ sóng của thiết bị. Nếu macOS hỏi, hãy bấm Cho phép.")
                .foregroundStyle(.secondary)
            HStack {
                Image(systemName: model.power == .poweredOn ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(model.power == .poweredOn ? .green : .orange)
                Text(powerText)
            }
            if model.power == .unauthorized {
                Button("Mở Cài đặt quyền Bluetooth") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!)
                }
                .pointingHandCursor()
            }
        }
    }

    private var powerText: String {
        switch model.power {
        case .poweredOn: return "Bluetooth đã sẵn sàng"
        case .poweredOff: return "Bluetooth đang tắt, hãy bật lên"
        case .unauthorized: return "Tether chưa có quyền Bluetooth"
        case .unsupported: return "Mac này không hỗ trợ Bluetooth LE"
        case .unknown: return "Đang kiểm tra Bluetooth…"
        }
    }

    private var device: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chọn thiết bị").font(.title.bold())
            Text("Có thể chọn iPhone, Apple Watch, hoặc cả hai.")
                .foregroundStyle(.secondary)
            Picker("Chọn thiết bị cho", selection: $pickingFor) {
                ForEach(DeviceKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .pointingHandCursor()
            HStack(alignment: .firstTextBaseline) {
                Text("Đưa \(pickingFor.title) sát Mac rồi bấm vào thiết bị có sóng mạnh nhất. Không cần cài app gì lên \(pickingFor.title).")
                    .font(.callout).foregroundStyle(.secondary)
                AccuracyInfo()
            }
            DeviceListView(pickingFor: pickingFor)
            ForEach(DeviceKind.allCases.filter { settings.deviceID($0) != nil }) { kind in
                Label("\(settings.deviceName(kind) ?? kind.title) · \(model.connection(kind).title)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private var desk: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ngồi ở bàn làm việc").font(.title.bold())
            Text("Để \(calibrationDeviceName) ở chỗ bạn hay để khi làm việc (trên bàn, trong túi…). Tether sẽ đo trong 8 giây.")
            measureView(deskMeasure)
            Button("Bắt đầu đo") { Task { await run(desk: true, countdown: 0) } }
                .pointingHandCursor()
                .disabled(isBusy(deskMeasure))
        }
    }

    private var away: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Đi tới chỗ muốn Mac khoá").font(.title.bold())
            Text("Bấm nút, rồi trong 10 giây mang thiết bị tới chỗ mà từ đó Mac nên khoá (ví dụ cửa phòng). Đứng yên ở đó tới khi nghe tiếng báo, rồi quay lại.")
            measureView(awayMeasure)
            Button("Bắt đầu (đo sau 10 giây)") { Task { await run(desk: false, countdown: 10) } }
                .pointingHandCursor()
                .disabled(isBusy(awayMeasure))
            if case .finished = awayMeasure, result == nil {
                Text("Hai vị trí có sóng quá giống nhau. Hãy đi xa hơn rồi đo lại, hoặc chỉnh tay trong Cài đặt.")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Xong rồi!").font(.largeTitle.bold())
            if let result {
                Text("Mac khoá khi sóng yếu hơn \(Int(result.far)) dBm trong \(Int(settings.lockDelay)) giây, và coi là bạn đã quay lại khi sóng mạnh hơn \(Int(result.near)) dBm.")
            } else {
                Text("Tether dùng ngưỡng mặc định. Bạn có thể chỉnh trong Cài đặt › Tổng quan.")
            }
            Text("Tether nằm trên thanh menu. Bấm vào icon để tạm dừng, khoá thử hoặc mở Cài đặt.")
                .foregroundStyle(.secondary)
            Text("Mẹo: bật “Dùng Apple Watch để mở khoá” trong Cài đặt hệ thống › Touch ID & Mật khẩu để mở Mac nhanh hơn.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if step != .permission && step != .done {
                Button("Quay lại") { step = Step(rawValue: step.rawValue - 1) ?? .permission }
                    .pointingHandCursor()
            }
            Spacer()
            if step == .desk || step == .away {
                Button("Bỏ qua hiệu chỉnh") { result = nil; step = .done }
                    .pointingHandCursor()
            }
            Button(step == .done ? "Hoàn tất" : "Tiếp tục") { next() }
                .pointingHandCursor()
                .keyboardShortcut(.defaultAction)
                .disabled(!canContinue)
        }
    }

    private var canContinue: Bool {
        switch step {
        case .permission: return model.power == .poweredOn
        case .device: return settings.hasAnyDevice
        case .desk: if case .finished = deskMeasure { return true } else { return false }
        case .away: return result != nil
        case .done: return true
        }
    }

    private func next() {
        switch step {
        case .away:
            if let result {
                settings.farThreshold = result.far
                settings.nearThreshold = result.near
            }
            step = .done
        case .done:
            settings.hasCompletedOnboarding = true
            onFinish()
        default:
            step = Step(rawValue: step.rawValue + 1) ?? .done
        }
    }

    // MARK: Measuring

    @ViewBuilder
    private func measureView(_ m: Measure) -> some View {
        HStack {
            switch m {
            case .idle: EmptyView()
            case .countdown(let s): Text("Bắt đầu đo sau \(s) giây…").monospacedDigit()
            case .measuring: ProgressView().controlSize(.small); Text("Đang đo…")
            case .finished(let v): Image(systemName: "checkmark.circle.fill").foregroundStyle(.green); Text("Trung bình \(Int(v)) dBm")
            case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red); Text("Không nhận được tín hiệu. Kiểm tra thiết bị đã kết nối chưa.")
            }
        }
    }

    private func isBusy(_ m: Measure) -> Bool {
        switch m {
        case .countdown, .measuring: return true
        default: return false
        }
    }

    private func run(desk: Bool, countdown: Int) async {
        func set(_ m: Measure) { if desk { deskMeasure = m } else { awayMeasure = m } }
        for s in stride(from: countdown, to: 0, by: -1) {
            set(.countdown(s))
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        set(.measuring)
        let avg = await model.measureAverageRSSI(duration: 8)
        NSSound.beep()
        set(avg.map { .finished($0) } ?? .failed)
        updateResult()
    }

    private func updateResult() {
        guard case .finished(let d) = deskMeasure, case .finished(let a) = awayMeasure else { result = nil; return }
        result = Calibration.thresholds(deskRSSI: d, awayRSSI: a)
    }

}
