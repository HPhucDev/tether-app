import AppKit

enum DockIconMode: String, CaseIterable, Identifiable {
    case whileWindowOpen
    case always
    case never
    var id: String { rawValue }
    var title: String {
        switch self {
        case .whileWindowOpen: return "Khi mở cửa sổ"
        case .always: return "Luôn hiện"
        case .never: return "Không hiện"
        }
    }
}

/// Decides whether Tether shows in the Dock, and brings its windows to the front.
/// Tether is a menu bar app (LSUIElement); macOS won't focus its windows unless it is a regular app,
/// so by default it becomes regular while a window is open and goes back to the menu bar afterwards.
@MainActor
enum WindowFocus {
    private static var openWindows: Set<ObjectIdentifier> = []
    static var dockMode: DockIconMode = .whileWindowOpen {
        didSet { updatePolicy() }
    }

    static func present(_ window: NSWindow) {
        openWindows.insert(ObjectIdentifier(window))
        updatePolicy()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    static func windowDidClose(_ window: NSWindow) {
        openWindows.remove(ObjectIdentifier(window))
        updatePolicy()
    }

    static func updatePolicy() {
        let showInDock: Bool
        switch dockMode {
        case .always: showInDock = true
        case .never: showInDock = false
        case .whileWindowOpen: showInDock = !openWindows.isEmpty
        }
        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        if showInDock {
            // An LSUIElement app that turns regular at runtime gets a blank Dock tile unless the icon is set explicitly.
            NSApp.applicationIconImage = NSImage(named: "AppIcon") ?? NSImage(named: NSImage.applicationIconName)
        }
    }
}

/// Base for Tether's AppKit-managed windows: builds on demand, tears down on close
/// so SwiftUI `onDisappear` runs and Bluetooth discovery stops.
@MainActor
class ManagedWindow: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?

    /// Subclasses return the window's content.
    func makeContentViewController() -> NSViewController { NSViewController() }
    func configure(_ window: NSWindow) {}

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: makeContentViewController())
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            configure(w)
            w.center()
            window = w
        }
        if let window { WindowFocus.present(window) }
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow else { return }
        WindowFocus.windowDidClose(w)
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                w.contentViewController = nil
                if self?.window === w { self?.window = nil }
            }
        }
    }
}
