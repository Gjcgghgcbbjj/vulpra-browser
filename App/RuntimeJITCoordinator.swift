import Foundation
import Darwin
import os

final class RuntimeJITCoordinator {
    static let shared = RuntimeJITCoordinator()

    private static let childNotification = Notification.Name("GeckoRuntime.ChildProcessDidStart")

    /// The Gecko content process polls for a JIT readiness signal for at most
    /// five seconds (`IOSBootstrap.mm`: `poll(&descriptor, 1, 5000)`). This
    /// deadline must not fire ahead of a slow-but-successful attach, so it is
    /// aligned with the engine's window instead of the earlier 4.5 s value.
    private static let readinessDeadlineSeconds: TimeInterval = 5.0

    private let logger = Logger(subsystem: "com.vulpra.browser", category: "jit-runtime")
    private let attachQueue = DispatchQueue(
        label: "com.vulpra.browser.jit-runtime.attach",
        qos: .userInitiated
    )
    private let stateQueue = DispatchQueue(label: "com.vulpra.browser.jit-runtime.state")
    private let preflightQueue = DispatchQueue(
        label: "com.vulpra.browser.jit-runtime.preflight",
        qos: .utility
    )

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

        preflightJITProviderIfNeeded()
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

    // MARK: - JIT capability detection

    /// TrollStore and jailbroken installs carry the no-sandbox entitlement and
    /// use the fast local `ptrace_jit` path instead of the DDI pairing path.
    private func usePtraceJIT() -> Bool {
        getEntitlementValue("com.apple.private.security.no-sandbox")
    }

    /// True on T4-class hardware (A18/M4 and newer) running iOS 26+, where
    /// SpiderMonkey must use the transactional-memory JIT path with a
    /// persistent debugger session (`hasTXMSupport` in the engine). Reporting
    /// this correctly is what keeps JIT working on iOS 26+ devices.
    private func hasTXMSupport() -> Bool {
        var systemInfo = utsname()
        uname(&systemInfo)
        let hardware = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }

        if #available(iOS 27.0, *) {
            return hardware != "iPad8,11" && hardware != "iPad8,12"
        }

        if #available(iOS 26.0, *) {
            let pattern = hardware.hasPrefix("iPad")
            ? #"iPad(\d+),(\d+)"#
            : #"iPhone(\d+),(\d+)"#
            let threshold: Double = hardware.hasPrefix("iPad") ? 14.5 : 14.2

            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: hardware,
                    range: NSRange(hardware.startIndex..., in: hardware)
                  ),
                  let majorRange = Range(match.range(at: 1), in: hardware),
                  let minorRange = Range(match.range(at: 2), in: hardware),
                  let major = Double(hardware[majorRange]),
                  let minor = Double(hardware[minorRange])
            else {
                return false
            }

            let divisor = pow(10.0, Double(String(Int(minor)).count))
            let version = major + (minor / divisor)
            return version >= threshold
        }

        return false
    }

    private func deviceOSVersion() -> DeviceOSVersion {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return DeviceOSVersion(
            majorVersion: Int32(version.majorVersion),
            minorVersion: Int32(version.minorVersion),
            patchVersion: Int32(version.patchVersion)
        )
    }

    private func runtimeInfo() -> JITRuntimeInfo {
        JITRuntimeInfo(
            hasTXMSupport: hasTXMSupport() ? 1 : 0,
            deviceOSVersion: deviceOSVersion()
        )
    }

    // MARK: - DDI preflight

    /// On non-TrollStore installs the DDI pairing path is the only way to get
    /// JIT. Warm it up in the background (download the Developer Disk Image if
    /// missing, then mount it and create the pairing provider) so the first
    /// content-process attach is fast enough to fit the five-second window.
    private func preflightJITProviderIfNeeded() {
        guard !usePtraceJIT() else {
            return
        }

        preflightQueue.async { [weak self] in
            self?.ensureDDIFilesThenWarmProvider()
        }
    }

    private func ensureDDIFilesThenWarmProvider() {
        if DDIManager.shared.hasRequiredDDIFiles() {
            warmProvider()
            return
        }

        logger.info("DDI files missing, starting background download preflight")
        DDIManager.shared.ensureRequiredDDIFiles(
            progress: { _ in },
            completion: { [weak self] result in
                guard let self else {
                    return
                }
                switch result {
                case .success:
                    self.preflightQueue.async { self.warmProvider() }
                case .failure(let error):
                    self.logger.error("DDI download preflight failed: \(error.localizedDescription)")
                }
            }
        )
    }

    private func warmProvider() {
        do {
            if try JITEnabler.shared.preflightJITProvider() {
                logger.info("JIT DDI provider preflight ready")
            } else {
                logger.error("JIT DDI provider preflight unavailable")
            }
        } catch {
            logger.error("JIT DDI provider preflight failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Child process handling

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

        stateQueue.asyncAfter(deadline: .now() + Self.readinessDeadlineSeconds) { [weak self] in
            self?.finish(pid: pid, enabled: false, reason: "deadline")
        }

        attachQueue.async { [weak self] in
            guard let self else {
                return
            }
            do {
                try JITEnabler.shared.enableJIT(forPID: pid, hasTXMSupport: hasTXMSupport())
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
}
