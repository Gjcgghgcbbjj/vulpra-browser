import Foundation

/// Serializes any Gecko JS-touching work until the main process has finished
/// enough bootstrap for AutoJSAPI. Device IPS shows AutoJSAPI::Init(null) when
/// GeckoView IPC (window open / WebExtension:List / setLocale) runs too early.
public enum GeckoEngineGate {
    private static let lock = NSLock()
    private static var ready = false
    private static var armed = false
    private static var waiters: [() -> Void] = []
    private static var bootstrapDeadline = Date.distantFuture
    /// Cold start needs longer than a restored UI path; 3s covers iOS 16 device.
    private static let bootstrapSeconds: TimeInterval = 3.0

    public static var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return ready
    }

    /// Call once from production main immediately before `GeckoRuntime.main`.
    public static func armFromStartup() {
        lock.lock()
        if armed {
            lock.unlock()
            return
        }
        armed = true
        bootstrapDeadline = Date().addingTimeInterval(bootstrapSeconds)
        lock.unlock()
        scheduleBootstrapIfNeeded()
    }

    /// Run `body` on the main queue once the engine may touch JS/globals.
    public static func whenReady(_ body: @escaping () -> Void) {
        armFromStartupIfNeeded()
        lock.lock()
        if ready {
            lock.unlock()
            runOnMain(body)
            return
        }
        waiters.append(body)
        lock.unlock()
        scheduleBootstrapIfNeeded()
    }

    private static func armFromStartupIfNeeded() {
        lock.lock()
        let needsArm = !armed
        if needsArm {
            armed = true
            bootstrapDeadline = Date().addingTimeInterval(bootstrapSeconds)
        }
        lock.unlock()
        if needsArm {
            scheduleBootstrapIfNeeded()
        }
    }

    private static func scheduleBootstrapIfNeeded() {
        lock.lock()
        let readyNow = ready
        let deadline = bootstrapDeadline
        lock.unlock()
        if readyNow { return }

        let delay = max(0, deadline.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            DispatchQueue.main.async {
                flushReady()
            }
        }
    }

    private static func flushReady() {
        lock.lock()
        if ready {
            lock.unlock()
            return
        }
        ready = true
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        for work in pending {
            runOnMain(work)
        }
    }

    private static func runOnMain(_ body: @escaping () -> Void) {
        if Thread.isMainThread {
            body()
        } else {
            DispatchQueue.main.async(execute: body)
        }
    }
}
