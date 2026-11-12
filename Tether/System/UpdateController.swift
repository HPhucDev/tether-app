import AppKit
import Sparkle
import SwiftUI

/// "Kiểm tra cập nhật" through Sparkle 2. Never checks on its own: SUEnableAutomaticChecks is off
/// in Tether-Info.plist, and the only entry point is `check()`, called from a button.
/// Sparkle's window shows the new version and its release notes; nothing is installed until the
/// user clicks "Install Update". Downloading runs in Sparkle's Downloader XPC service, so Tether
/// itself keeps having no network entitlement.
@MainActor
final class UpdateController: NSObject, ObservableObject, SPUStandardUserDriverDelegate {
    static let shared = UpdateController()

    @Published private(set) var canCheck = false
    @Published private(set) var lastCheck: Date?

    private lazy var controller: SPUStandardUpdaterController = {
        let c = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        c.updater.automaticallyChecksForUpdates = false
        c.updater.automaticallyDownloadsUpdates = false
        c.updater.publisher(for: \.canCheckForUpdates).receive(on: DispatchQueue.main).assign(to: &$canCheck)
        c.updater.publisher(for: \.lastUpdateCheckDate).receive(on: DispatchQueue.main).assign(to: &$lastCheck)
        return c
    }()

    /// Starts Sparkle (no network until `check()`), so the button knows whether it can run.
    func prepare() {
        _ = controller
    }

    func check() {
        bringToFront()
        controller.checkForUpdates(nil)
    }

    // A menu bar app isn't frontmost, so Sparkle's windows would open behind others.
    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
    }

    nonisolated func standardUserDriverWillShowModalAlert() {
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }
}

/// "Kiểm tra cập nhật…" button, disabled while a check is already running.
struct CheckForUpdatesButton: View {
    @ObservedObject private var updates = UpdateController.shared
    var title = "Kiểm tra cập nhật…"

    var body: some View {
        Button(title) { updates.check() }
            .disabled(!updates.canCheck)
            .pointingHandCursor()
            .onAppear { updates.prepare() }
    }
}


extension Bundle {
    /// "0.2.1 (5)"
    var appVersion: String {
        let v = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}
