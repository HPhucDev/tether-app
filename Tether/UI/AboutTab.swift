import AppKit
import SwiftUI

struct AboutTab: View {
    private let info = Bundle.main.infoDictionary ?? [:]
    private var version: String { info["CFBundleShortVersionString"] as? String ?? "—" }
    private var build: String { info["CFBundleVersion"] as? String ?? "—" }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 88, height: 88)
                    Text("Tether").font(.largeTitle.bold())
                    Text("Phiên bản \(version) (\(build))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("Sợi dây vô hình giữa bạn và Mac.")
                        .font(.title3)
                        .padding(.top, 2)
                }

                PrivacySection()

                VStack(spacing: 6) {
                    Text("Tether giúp bạn khỏi quên khoá máy, không thay thế mật khẩu hay bảo mật của macOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    AboutFooter()
                    CoffeeButton(name: "S1mple")
                        .padding(.top, 20)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
    }
}

/// "Bảo vệ bạn, không theo dõi bạn." + six short promise cards.
private struct PrivacySection: View {
    private let cards: [(title: String, detail: String)] = [
        ("Không mạng", "Sandbox chặn mọi kết nối. Tether không thể gửi gì ra ngoài."),
        ("Không thu thập", "Không analytics, không cloud. Mọi thứ nằm trên Mac."),
        ("Chỉ lắng nghe", "Chỉ đo sóng thiết bị tự phát. Không kết nối, không gửi lệnh."),
        ("Quyền tối thiểu", "Chỉ Bluetooth và Thông báo. Không file, vị trí, camera."),
        ("App Sandbox", "Chạy trong hộp cát của Apple với đúng một quyền: Bluetooth."),
        ("Tự kiểm chứng", "Activity Monitor › Network: luôn 0 byte."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("QUYỀN RIÊNG TƯ & BẢO MẬT")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.green)
                Text("Bảo vệ bạn,\nkhông theo dõi bạn.")
                    .font(.system(size: 26, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                (Text("Một nguyên tắc duy nhất: ")
                    + Text("không một byte dữ liệu nào rời khỏi Mac.").bold().foregroundColor(.primary))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(cards, id: \.title) { card in
                    PrivacyCard(title: card.title, detail: card.detail)
                }
            }
        }
    }
}

private struct PrivacyCard: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, .green)
                    .font(.system(size: 16))
                Text(title).font(.headline)
            }
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
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
