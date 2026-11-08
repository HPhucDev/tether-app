import AppKit

enum SystemSettings {
    /// Opens System Settings › Touch ID & Password (where "Use Apple Watch to unlock" lives).
    static func openTouchIDAndPassword() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Touch-ID-Settings.extension",  // macOS 13+
            "x-apple.systempreferences:com.apple.preferences.password",         // Macs without Touch ID
            "x-apple.systempreferences:com.apple.preference.security",
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) { return }
        }
    }
}
