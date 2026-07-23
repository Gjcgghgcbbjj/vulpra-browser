import Foundation

/// Serializes the first Gecko window open until the main process has had time to
/// finish JS/global bootstrap. Device crashes showed AutoJSAPI::Init(null) when a
/// session was opened ~0.7s after launch on iOS 16.
enum GeckoEngineGate {
    private static let lock = NSLock()
    private static var ready = false
    private static var waiters: [() -> Void] = []
    private static let bootstrapDeadline = Date().addingTimeInterval(1.5)

    /// True after the first bootstrap window has been allowed.
    static var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return ready
    }

    /// Run `body` on the main queue once the engine may open windows.
    static func whenReady(_ body: @escaping () -> Void) {
        lock.lock()
        if ready {
            lock.unlock()
            if Thread.isMainThread {
                body()
            } else {
                DispatchQueue.main.async(execute: body)
            }
            return
        }
        waiters.append(body)
        let shouldSchedule = waiters.count == 1
        lock.unlock()

        guard shouldSchedule else { return }
        scheduleBootstrap()
    }

    private static func scheduleBootstrap() {
        let delay = max(0, bootstrapDeadline.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // One extra run-loop turn after the delay so XRE can finish nested work.
            DispatchQueue.main.async {
                flushReady()
            }
        }
    }

    private static func flushReady() {
        lock.lock()
        ready = true
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        for work in pending {
            work()
        }
    }
}
