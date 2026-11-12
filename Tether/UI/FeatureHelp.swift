import SwiftUI

// MARK: - "New" tracking

/// Features introduced recently. Each shows a "Mới" tag until the user first uses it.
enum NewFeature: String, CaseIterable {
    case distancePresets, sensitivity, schedule, wakeOnReturn, shortcuts, deskTime, breakReminder
}

/// Remembers which new features the user has already touched. Stored only on this Mac.
@MainActor
final class NewFeatureStore: ObservableObject {
    @Published private(set) var seen: Set<String>
    private let defaults: UserDefaults
    private let key = "seenNewFeatures"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        seen = Set(defaults.stringArray(forKey: key) ?? [])
    }

    func isNew(_ feature: NewFeature) -> Bool { !seen.contains(feature.rawValue) }

    var hasUnseen: Bool { NewFeature.allCases.contains(where: isNew) }

    func markSeen(_ feature: NewFeature) {
        guard isNew(feature) else { return }
        seen.insert(feature.rawValue)
        defaults.set(Array(seen), forKey: key)
    }
}

/// Small "Mới" capsule, hidden once the feature has been used.
struct NewBadge: View {
    @EnvironmentObject private var store: NewFeatureStore
    let feature: NewFeature

    var body: some View {
        if store.isNew(feature) {
            Text("Mới")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .accessibilityLabel("Tính năng mới")
        }
    }
}

// MARK: - Info button

/// ⓘ that explains a feature. Hovering shows the explanation (clicking works too).
struct InfoButton: View {
    let title: String
    let text: String
    @State private var isShown = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Button {
            hoverTask?.cancel()
            isShown.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { inside in
            hoverTask?.cancel()
            if inside {
                // Short delay so passing the mouse over doesn't flash popovers.
                hoverTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if !Task.isCancelled { isShown = true }
                }
            }
        }
        .accessibilityLabel("Giới thiệu: \(title)")
        .popover(isPresented: $isShown, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 300, alignment: .leading)
            .padding(14)
        }
    }
}

// MARK: - Row label

/// Title (+ ⓘ and "Mới" tag) with an optional one-line hint under it.
struct FeatureLabel: View {
    let title: String
    var hint: String?
    var info: String?
    var feature: NewFeature?

    init(_ title: String, hint: String? = nil, info: String? = nil, new feature: NewFeature? = nil) {
        self.title = title
        self.hint = hint
        self.info = info
        self.feature = feature
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(title)
                if let info { InfoButton(title: title, text: info) }
                if let feature { NewBadge(feature: feature) }
            }
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Feature explanations

enum FeatureInfo {
    static let distance = """
    Mac khoá khi thiết bị ra xa hơn số mét bạn chọn.
    1–2 m: khoá ngay khi bạn rời ghế. 3–4 m: hợp phòng làm việc thông thường. 6–8 m: ít khoá nhầm hơn, hợp phòng rộng.
    Số mét chỉ là ước lượng vì cơ thể, tường và túi quần làm sóng yếu đi. Bấm “Đo theo phòng của bạn” để Tether tự tính theo chỗ ngồi thật.
    """
    static let sensitivity = """
    Độ nhạy càng cao, Tether càng phản ứng nhanh khi bạn rời đi, nhưng cũng dễ khoá nhầm hơn khi sóng chập chờn (iPhone trong túi, sau lưng ghế…).
    Thấp: ổn định nhất, coi là mất tín hiệu sau 14 giây.
    Vừa: mặc định, 10 giây.
    Cao: 7 giây.
    Rất cao: 5 giây, đo sóng mỗi 1 giây thay vì 1,5 giây, phản ứng gần như tức thì.
    """
    static let delay = "Tether chỉ khoá khi bạn ở xa liên tục đủ số giây này. Đứng dậy lấy đồ rồi quay lại ngay thì Mac không khoá. Chọn ngắn để an toàn hơn, chọn dài nếu Mac hay khoá nhầm."
    static let policy = "“Tất cả đều đi xa”: còn một thiết bị ở gần là coi như bạn vẫn ngồi đó, hợp khi để iPhone trên bàn và đeo Watch. “Một thiết bị bất kỳ đi xa”: chặt hơn, chỉ cần một thiết bị rời đi là khoá."
    static let schedule = "Chọn ngày và khung giờ Tether làm việc, ví dụ thứ 2 đến thứ 6, 8:00–18:00. Ngoài lịch, icon trên thanh menu đổi thành 🌙 và Tether không khoá Mac. Khung giờ qua đêm như 22:00–06:00 cũng được."
    static let wake = "Sau khi khoá Mac, Tether tiếp tục nghe sóng của thiết bị. Khi bạn mang thiết bị quay lại, màn hình tự sáng để bạn mở khoá ngay bằng Touch ID hoặc Apple Watch. Tether không bao giờ tự mở khoá. Tốn thêm chút pin vì phải nghe Bluetooth cả lúc Mac đang khoá; nếu Mac đã ngủ hẳn thì không bật được."
    static let shortcuts = "Tether chạy một phím tắt của bạn (trong app Phím tắt) khi bạn rời đi và khi bạn quay lại. Ví dụ: dừng nhạc, tắt tiếng, bật Không làm phiền, đổi trạng thái Slack thành Vắng mặt. Ngược lại, app Phím tắt có sẵn thao tác của Tether: Tạm dừng, Tiếp tục, Bật hoặc tắt, Khoá Mac ngay và Trạng thái."
    static let deskTime = "Tether cộng dồn thời gian thiết bị của bạn ở gần và Mac đang mở khoá, để bạn biết mỗi ngày ngồi máy bao lâu. Số liệu giữ 30 ngày và chỉ lưu trên Mac này."
    static let breakReminder = "Khi bạn ngồi liền đủ số phút đã chọn, Tether gửi thông báo nhắc đứng dậy vận động. Rời bàn hơn 2 phút là tính lại từ đầu."
}
