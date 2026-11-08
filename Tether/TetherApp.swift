import AppKit
import SwiftUI

@main
struct TetherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPopoverView()
                .environmentObject(model)
                .environmentObject(model.settings)
        } label: {
            Image(systemName: model.status.symbolName)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Giới thiệu Tether") { SettingsWindow.shared.show(tab: .about) }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Cài đặt…") { SettingsWindow.shared.show() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            let model = AppModel.shared
            model.start()
            if !model.settings.hasCompletedOnboarding {
                OnboardingWindow.shared.show()
            }
        }
    }

    /// Opening Tether again (Finder, Launchpad, Spotlight, Dock) while it runs shows Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated {
            if !flag { SettingsWindow.shared.show() }
        }
        return true
    }
}

// MARK: - Windows

@MainActor
final class SettingsWindow: ManagedWindow {
    static let shared = SettingsWindow()

    enum Tab: Int { case devices, distance, history, general, about }
    private var pendingTab: Tab?

    func show(tab: Tab) {
        pendingTab = tab
        show()
    }

    override func show() {
        super.show()
        if let tab = pendingTab, let tabs = window?.contentViewController as? SettingsTabController {
            tabs.selectedTabViewItemIndex = tab.rawValue
        }
        pendingTab = nil
    }

    override func makeContentViewController() -> NSViewController {
        let model = AppModel.shared
        let tabs = SettingsTabController()
        tabs.tabStyle = .toolbar
        func add<V: View>(_ view: V, _ label: String, _ symbol: String) {
            let host = NSHostingController(rootView: view
                .environmentObject(model)
                .environmentObject(model.settings)
                .environmentObject(model.lockHistory))
            host.sizingOptions = [.preferredContentSize]
            // The tab controller copies the selected child's title to the window; without one it shows "Untitled".
            host.title = label
            let item = NSTabViewItem(viewController: host)
            item.label = label
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            tabs.addTabViewItem(item)
        }
        add(DevicesTab().frame(width: 560, height: 580), "Thiết bị", "iphone")
        add(DistanceTab().frame(width: 600, height: 760), "Khoảng cách", "dot.radiowaves.left.and.right")
        add(HistoryTab().frame(width: 560, height: 520), "Lịch sử", "clock.arrow.circlepath")
        add(GeneralTab().frame(width: 560, height: 560), "Chung", "gearshape")
        add(AboutTab().frame(width: 600, height: 760), "Giới thiệu", "info.circle")
        return tabs
    }

    override func configure(_ window: NSWindow) {
        window.styleMask.remove(.miniaturizable)
        window.toolbarStyle = .preference
        window.title = "Thiết bị"
    }
}

/// Keeps the window title in sync with the selected tab, like System Settings.
final class SettingsTabController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        view.window?.title = tabViewItem?.label ?? "Tether"
    }
}

@MainActor
final class OnboardingWindow: ManagedWindow {
    static let shared = OnboardingWindow()

    override func makeContentViewController() -> NSViewController {
        let model = AppModel.shared
        let root = OnboardingView(onFinish: { [weak self] in self?.close() })
            .environmentObject(model)
            .environmentObject(model.settings)
        return NSHostingController(rootView: root)
    }

    override func configure(_ window: NSWindow) {
        window.title = "Thiết lập Tether"
        window.styleMask.remove(.miniaturizable)
    }
}

/// Opens Tether's Settings window from anywhere (popover, onboarding…).
struct OpenSettingsButton: View {
    var title = "Cài đặt…"
    var tab: SettingsWindow.Tab = .devices

    var body: some View {
        Button(title) { SettingsWindow.shared.show(tab: tab) }
            .pointingHandCursor()
    }
}
