import AppKit
import CoreGraphics
import Foundation

/// Screen lock/unlock, sleep/wake, and App Nap prevention.
@MainActor
final class SystemObserver {
    var onScreenLocked: (() -> Void)?
    var onScreenUnlocked: (() -> Void)?
    var onWillSleep: (() -> Void)?
    var onDidWake: (() -> Void)?

    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var activity: NSObjectProtocol?

    nonisolated static var isScreenLockedNow: Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (dict["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    func start() {
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Tether monitors Bluetooth proximity")

        let dnc = DistributedNotificationCenter.default()
        observe(dnc, "com.apple.screenIsLocked") { $0.onScreenLocked?() }
        observe(dnc, "com.apple.screenIsUnlocked") { $0.onScreenUnlocked?() }

        let wnc = NSWorkspace.shared.notificationCenter
        observe(wnc, NSWorkspace.willSleepNotification.rawValue) { $0.onWillSleep?() }
        observe(wnc, NSWorkspace.didWakeNotification.rawValue) { $0.onDidWake?() }
    }

    private func observe(_ center: NotificationCenter, _ name: String, _ handler: @escaping @MainActor (SystemObserver) -> Void) {
        let token = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
        tokens.append((center, token))
    }
}
