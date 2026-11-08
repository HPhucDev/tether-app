import AppKit
import SwiftUI

struct AboutTab: View {
    private let info = Bundle.main.infoDictionary ?? [:]
    private var version: String { info["CFBundleShortVersionString"] as? String ?? "—" }
    private var build: String { info["CFBundleVersion"] as? String ?? "—" }
    @State private var guide: FeatureGuide?

    var body: some View {
        VStack(spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Tether").font(.title.bold())
                            Text("Phiên bản \(version) (\(build))")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Text("Sợi dây vô hình giữa bạn và Mac.")
                            .font(.title3)
                        Label("Không cần kết nối mạng, không thu thập dữ liệu.", systemImage: "lock.shield.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tính năng")
                        .font(.headline)
                    VStack(spacing: 0) {
                        ForEach(FeatureGuide.all) { item in
                            if item.id != FeatureGuide.all.first?.id { Divider().padding(.leading, 44) }
                            FeatureRow(guide: item) { guide = item }
                        }
                    }
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
                }

                VStack(spacing: 6) {
                    Text("Tether giúp bạn khỏi quên khoá máy, không thay thế mật khẩu hay bảo mật của macOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    AboutFooter()
                    CoffeeButton(name: "S1mple")
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(item: $guide) { FeatureGuideSheet(guide: $0) }
    }
}

/// One feature with a short how-to, shown from the About tab.
struct FeatureGuide: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let summary: String
    let steps: [String]
    var tab: SettingsWindow.Tab?
    var tabTitle: String?

    static let all: [FeatureGuide] = [
        FeatureGuide(
            id: "autolock", symbol: "lock.shield", title: "Tự khoá khi bạn rời đi",
            summary: "Mang iPhone, Watch hoặc AirPods đi xa, Mac tự khoá.",
            steps: [
                "Mở Cài đặt › Tổng quan, bấm “Thêm thiết bị…” và chọn iPhone, Apple Watch hoặc AirPods của bạn.",
                "Chọn khoảng cách khoá: Gần, Vừa hoặc Xa.",
                "Chọn thời gian chờ trước khi khoá.",
                "Thử đi ra xa: Mac khoá sau số giây đã chọn. Quay lại thì mở khoá như bình thường.",
                "Hay khoá nhầm hoặc khoá muộn? Bấm “Đo theo phòng của bạn…” để Tether tự tính khoảng cách cho chỗ ngồi thật.",
            ],
            tab: .overview, tabTitle: "Mở Tổng quan"),
        FeatureGuide(
            id: "schedule", symbol: "calendar", title: "Lịch hoạt động",
            summary: "Chỉ bảo vệ trong những ngày, giờ bạn chọn.",
            steps: [
                "Mở Cài đặt › Tự động, bật “Chỉ bảo vệ theo lịch”.",
                "Chọn các ngày trong tuần.",
                "Chọn giờ bắt đầu và kết thúc. Khung giờ qua đêm như 22:00–06:00 cũng được.",
                "Ngoài lịch, icon trên thanh menu chuyển sang 🌙 và Tether không khoá Mac.",
            ],
            tab: .automation, tabTitle: "Mở Tự động"),
        FeatureGuide(
            id: "wake", symbol: "sun.max", title: "Sáng màn hình khi quay lại",
            summary: "Mac sáng sẵn để bạn mở khoá ngay.",
            steps: [
                "Mở Cài đặt › Tự động, bật “Bật sáng màn hình chờ sẵn”.",
                "Khi Tether khoá Mac và bạn mang thiết bị quay lại, màn hình tự sáng.",
                "Mở khoá bằng Touch ID, mật khẩu hoặc Apple Watch. Tether không bao giờ tự mở khoá.",
            ],
            tab: .automation, tabTitle: "Mở Tự động"),
        FeatureGuide(
            id: "shortcuts", symbol: "square.2.layers.3d", title: "Phím tắt",
            summary: "Tự chạy việc bạn muốn khi rời đi và khi quay lại.",
            steps: [
                "Tạo phím tắt trong app Phím tắt, ví dụ dừng nhạc hoặc bật Không làm phiền.",
                "Mở Cài đặt › Tự động, chọn phím tắt cho “Khi rời đi” và “Khi quay lại”.",
                "Bấm “Thử” để chạy thử ngay.",
                "Trong app Phím tắt cũng có thao tác của Tether: Tạm dừng, Tiếp tục, Bật hoặc tắt, Khoá Mac ngay, Trạng thái.",
            ],
            tab: .automation, tabTitle: "Mở Tự động"),
        FeatureGuide(
            id: "desk", symbol: "chart.bar", title: "Thời gian ngồi bàn và nhắc nghỉ",
            summary: "Biết mỗi ngày ngồi máy bao lâu, được nhắc đứng dậy.",
            steps: [
                "Mở Cài đặt › Thống kê để xem thời gian ngồi bàn hôm nay và 7 ngày qua.",
                "Bật “Nhắc đứng dậy khi ngồi lâu” và chọn số phút.",
                "Khi ngồi liền đủ lâu, Tether gửi thông báo nhắc bạn vận động.",
            ],
            tab: .stats, tabTitle: "Mở Thống kê"),
        FeatureGuide(
            id: "history", symbol: "clock.arrow.circlepath", title: "Lịch sử khoá",
            summary: "Xem lại Mac đã tự khoá lúc nào và vì sao.",
            steps: [
                "Mở Cài đặt › Thống kê, kéo xuống mục “Lần khoá gần đây”.",
                "Rê chuột lên thời gian để xem giờ chính xác.",
            ],
            tab: .stats, tabTitle: "Mở Thống kê"),
    ]
}

private struct FeatureRow: View {
    let guide: FeatureGuide
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(systemName: guide.symbol)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(guide.title)
                    Text(guide.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
    }
}

private struct FeatureGuideSheet: View {
    let guide: FeatureGuide
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: guide.symbol)
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(guide.title).font(.title2.bold())
                    Text(guide.summary).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(guide.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(i + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.accentColor, in: Circle())
                        Text(step)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack {
                if let tab = guide.tab, let title = guide.tabTitle {
                    Button(title) {
                        dismiss()
                        SettingsWindow.shared.show(tab: tab)
                    }
                    .pointingHandCursor()
                }
                Spacer()
                Button("Xong") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .pointingHandCursor()
            }
        }
        .padding(22)
        .frame(width: 440, height: 360)
    }
}

/// "© 2026 S1mple · Website · LinkedIn · Substack · Feedback"
private struct AboutFooter: View {
    /// Links shown in the footer. Set a URL to nil to hide that link.
    private static let links: [(title: String, url: URL?)] = [
        ("Website", URL(string: "https://hoangphuc.io.vn/")),
        ("LinkedIn", URL(string: "https://www.linkedin.com/in/hoang-phuc-developer")),
        ("Substack", URL(string: "https://hphucdev.substack.com/")),
        ("GitHub", nil),   // TODO: GitHub profile URL
        ("Feedback", URL(string: "mailto:hoangphucdeveloper@gmail.com?subject=Tether%20feedback")),
    ]

    var body: some View {
        HStack(spacing: 6) {
            Text("© \(String(Calendar.current.component(.year, from: Date()))) S1mple")
            ForEach(Self.links.filter { $0.url != nil }, id: \.title) { link in
                Text("·")
                Link(link.title, destination: link.url!)
                    .pointingHandCursor()
                    .foregroundStyle(Color.accentColor)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// "☕ Một ly cà phê cho S1mple": click shows the donate QR card. No hover, so it never pops up by accident.
private struct CoffeeButton: View {
    let name: String
    @State private var isShown = false

    var body: some View {
        Button {
            isShown.toggle()
        } label: {
            Text("☕ Một ly cà phê cho \(name)")
                .font(.callout.weight(.medium))
                .underline()
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .popover(isPresented: $isShown, arrowEdge: .top) {
            VStack(spacing: 10) {
                Image("DonateQR")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("Quét mã, tuỳ lòng. Cảm ơn bạn!")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .accessibilityLabel("Ủng hộ \(name) một ly cà phê, hiện mã QR")
    }
}
