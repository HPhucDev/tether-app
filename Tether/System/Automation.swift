import AppKit
import IOKit.pwr_mgt
import os

/// Runs a user's shortcut from the Shortcuts app by name. Works inside the App Sandbox:
/// Tether only opens a `shortcuts://` URL, the Shortcuts app does the actual work.
enum ShortcutRunner {
    private static let log = Logger(subsystem: "com.simple.tether", category: "automation")

    static func run(_ name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var c = URLComponents()
        c.scheme = "shortcuts"
        c.host = "run-shortcut"
        c.queryItems = [URLQueryItem(name: "name", value: name)]
        guard let url = c.url else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open(url, configuration: config) { _, error in
            if let error {
                log.error("Shortcut \(name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            } else {
                log.notice("Ran shortcut \(name, privacy: .public)")
            }
        }
    }

    static func openShortcutsApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

/// Turns the display on (as if the user touched the keyboard) so the login window is ready.
/// It does not unlock anything.
enum DisplayWaker {
    private static let log = Logger(subsystem: "com.simple.tether", category: "automation")

    static func wake() {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionDeclareUserActivity("Tether: you came back" as CFString, kIOPMUserActiveLocal, &id)
        if result == kIOReturnSuccess {
            log.notice("Display woken")
            // The assertion only needs to nudge the display; release it shortly after.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { IOPMAssertionRelease(id) }
        } else {
            log.error("Could not wake display: \(result)")
        }
    }
}

/// The user's shortcuts, read with the system `shortcuts list` tool.
enum ShortcutLibrary {
    private static let log = Logger(subsystem: "com.simple.tether", category: "automation")

    /// Shortcut names sorted for display, or nil when the list can't be read.
    static func names() async -> [String]? {
        await Task.detached(priority: .userInitiated) { () -> [String]? in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            p.arguments = ["list"]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = Pipe()
            do {
                try p.run()
            } catch {
                log.error("shortcuts list failed to start: \(error.localizedDescription, privacy: .public)")
                return nil
            }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else {
                log.error("shortcuts list exited with \(p.terminationStatus)")
                return nil
            }
            let names = String(decoding: data, as: UTF8.self)
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            log.notice("shortcuts list returned \(names.count) shortcuts")
            return Array(Set(names)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }.value
    }
}
