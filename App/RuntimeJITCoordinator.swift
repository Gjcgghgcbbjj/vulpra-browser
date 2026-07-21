import Foundation
import os

final class RuntimeJITCoordinator {
    static let shared = RuntimeJITCoordinator()

    private static let childNotification = Notification.Name("GeckoRuntime.ChildProcessDidStart")

    private let logger = Logger(subsystem: "com.vulpra.browser", category: "jit-runtime")
    private let attachQueue = DispatchQueue(
        label: "com.vulpra.browser.jit-runtime.attach",
        qos: .userInitiated
    )
    private let stateQueue = DispatchQueue(label: "com.vulpra.browser.jit-runtime.state")

    private var observer: NSObjectProtocol?
    private var pendingPIDs: Set<Int32> = []
    private var completedPIDs: Set<Int32> = []
    private var isStarted = false
    private var isStopped = false

    private init() {}

    func start() {
        stateQueue.sync {
            guard !isStarted, !isStopped else {
                return
            }
            isStarted = true
            observer = NotificationCenter.default.addObserver(
                forName: Self.childNotification,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                self?.receive(notification)
            }
        }
    }

    func stop() {
        var observerToRemove: NSObjectProtocol?

        stateQueue.sync {
            guard isStarted, !isStopped else {
                return
            }
            isStopped = true
            observerToRemove = observer
            observer = nil

            let pending = pendingPIDs.sorted()
            for pid in pending {
                finish(pid: pid, enabled: false, reason: "teardown")
            }
        }

        if let observer = observerToRemove {
            NotificationCenter.default.removeObserver(observer)
        }
        JITEnabler.shared.detachAllJITSessions()
    }

    private func receive(_ notification: Notification) {
        guard
            let pidNumber = notification.userInfo?["pid"] as? NSNumber,
            let rawProcessType = notification.userInfo?["processType"] as? String
        else {
            logger.error("Ignoring Gecko child notification without pid or process type")
            return
        }

        let pid = pidNumber.int32Value
        guard pid > 0 else {
            logger.error("Ignoring Gecko child notification with invalid pid")
            return
        }

        let processType = rawProcessType
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        stateQueue.async { [weak self] in
            self?.begin(pid: pid, processType: processType)
        }
    }

    private func begin(pid: Int32, processType: String) {
        guard !isStopped else {
            return
        }
        guard !pendingPIDs.contains(pid), !completedPIDs.contains(pid) else {
            logger.debug("Ignoring duplicate Gecko child pid \(pid)")
            return
        }

        pendingPIDs.insert(pid)
        guard processType == "tab" else {
            finish(pid: pid, enabled: false, reason: "non-tab")
            return
        }

        stateQueue.asyncAfter(deadline: .now() + 4.5) { [weak self] in
            self?.finish(pid: pid, enabled: false, reason: "deadline")
        }

        attachQueue.async { [weak self] in
            guard let self else {
                return
            }
            do {
                try JITEnabler.shared.enableJIT(forPID: pid, hasTXMSupport: false)
                stateQueue.async { [weak self] in
                    self?.finish(pid: pid, enabled: true, reason: "attached")
                }
            } catch {
                logger.error("JIT attachment failed for pid \(pid): \(error.localizedDescription)")
                stateQueue.async { [weak self] in
                    self?.finish(pid: pid, enabled: false, reason: "attachment-failed")
                }
            }
        }
    }

    private func finish(pid: Int32, enabled: Bool, reason: String) {
        guard pendingPIDs.remove(pid) != nil else {
            return
        }
        completedPIDs.insert(pid)
        ReportJITStatusForChild(pid, enabled, runtimeInfo())
        logger.info("Reported Gecko JIT status for pid \(pid): \(reason)")
    }

    private func runtimeInfo() -> JITRuntimeInfo {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return JITRuntimeInfo(
            hasTXMSupport: 0,
            deviceOSVersion: DeviceOSVersion(
                majorVersion: Int32(version.majorVersion),
                minorVersion: Int32(version.minorVersion),
                patchVersion: Int32(version.patchVersion)
            )
        )
    }
}
