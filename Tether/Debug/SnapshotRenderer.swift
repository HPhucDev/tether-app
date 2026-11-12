#if DEBUG
import AppKit
import SwiftUI

/// Debug-only: `TETHER_SNAPSHOT_DIR=/path open Tether.app` renders each settings tab and the
/// menu popover to PNGs (light and dark) and quits. Nothing starts scanning; settings are only read.
@MainActor
enum SnapshotRenderer {
    static func runIfRequested() -> Bool {
        guard let dir = ProcessInfo.processInfo.environment["TETHER_SNAPSHOT_DIR"] else { return false }
        let out = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let model = AppModel.shared
        if ProcessInfo.processInfo.environment["TETHER_SNAPSHOT_TALL"] != nil { fillTallestState(model) }

        func wrap<V: View>(_ v: V) -> some View {
            v.environmentObject(model)
                .environmentObject(model.settings)
                .environmentObject(model.lockHistory)
                .environmentObject(model.deskTime)
                .environmentObject(model.newFeatures)
        }
        let views: [(String, AnyView, CGSize)] = [
            ("overview", AnyView(wrap(OverviewTab())), CGSize(width: 560, height: 640)),
            ("automation", AnyView(wrap(AutomationTab())), CGSize(width: 560, height: 560)),
            ("stats", AnyView(wrap(StatsTab())), CGSize(width: 560, height: 630)),
            ("general", AnyView(wrap(GeneralTab())), CGSize(width: 560, height: 530)),
            ("about", AnyView(wrap(AboutTab())), CGSize(width: 560, height: 530)),
            ("popover", AnyView(wrap(MenuPopoverView())), CGSize(width: 300, height: 300)),
            ("picker", AnyView(wrap(DevicePickerSheet(initialKind: .iPhone))), CGSize(width: 540, height: 520)),
            ("advanced", AnyView(wrap(AdvancedDistanceView())), CGSize(width: 600, height: 680)),
        ]
        measurements = []
        for (name, view, size) in views {
            for dark in [false, true] {
                render(view.frame(width: size.width, height: size.height), size: size, dark: dark,
                       to: out.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
            }
        }
        try? measurements.joined(separator: "\n").write(to: out.appendingPathComponent("heights.txt"), atomically: true, encoding: .utf8)
        return true
    }

    private static var measurements: [String] = []

    /// Everything that makes the settings tabs taller: schedule rows, break options, two devices, history.
    private static func fillTallestState(_ model: AppModel) {
        let s = model.settings
        s.scheduleEnabled = true
        s.breakReminder = true
        s.setDevice(.iPhone, id: UUID(), name: "iPhone của bạn")
        s.setDevice(.watch, id: UUID(), name: "Apple Watch của bạn")
        for i in 0..<6 {
            model.lockHistory.record(LockEvent(date: Date().addingTimeInterval(Double(-i * 3600)), reason: .walkedAway, method: "sac", readings: []))
        }
    }

    private static func allSubviews(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(allSubviews)
    }

    private static func render(_ view: some View, size: CGSize, dark: Bool, to url: URL) {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -20000, y: -20000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.backgroundColor = dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.96, alpha: 1)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        if !dark {
            // Height the content really needs: the Form's scroll view document, or the view's fitting size.
            let scrolls = allSubviews(of: host).compactMap { $0 as? NSScrollView }
            let needed = scrolls.compactMap { $0.documentView?.frame.height }.max() ?? host.fittingSize.height
            measurements.append("\(url.deletingPathExtension().lastPathComponent): needs \(Int(needed.rounded())) of \(Int(size.height))")
        }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
    }
}
#endif
