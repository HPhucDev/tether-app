import AppKit
import os

/// Locks the screen from inside the App Sandbox.
/// 1. Private `SACLockScreenImmediate` (login.framework): instant lock, no settings needed.
/// 2. If the screen still isn't locked shortly after, start the screen saver. That locks when
///    "Require password immediately after screen saver begins" is on (macOS default for most users).
final class ScreenLocker {
    enum Method: String { case sac, screenSaver, failed }

    private typealias LockFunction = @convention(c) () -> Int32
    private let log = Logger(subsystem: "com.simple.tether", category: "lock")

    private lazy var sacLock: LockFunction? = {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        guard let handle = dlopen(path, RTLD_LAZY),
              let sym = dlsym(handle, "SACLockScreenImmediate") else {
            log.error("SACLockScreenImmediate unavailable")
            return nil
        }
        return unsafeBitCast(sym, to: LockFunction.self)
    }()

    /// Calls `completion` on the main queue with the method that ended up locking (or `.failed`).
    func lock(completion: ((Method) -> Void)? = nil) {
        if let sacLock {
            let result = sacLock()
            log.notice("SACLockScreenImmediate returned \(result)")
            verify(after: 1.0) { [weak self] locked in
                if locked {
                    completion?(.sac)
                } else {
                    self?.log.error("Screen not locked after SAC call, starting screen saver")
                    self?.startScreenSaver(completion: completion)
                }
            }
        } else {
            startScreenSaver(completion: completion)
        }
    }

    private func startScreenSaver(completion: ((Method) -> Void)?) {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            if let error {
                self?.log.error("Screen saver failed: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { completion?(.failed) }
                return
            }
            self?.log.notice("Started screen saver")
            DispatchQueue.main.async { completion?(.screenSaver) }
        }
    }

    private func verify(after delay: TimeInterval, _ check: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            check(SystemObserver.isScreenLockedNow)
        }
    }
}
