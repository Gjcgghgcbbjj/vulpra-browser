import Foundation
import os

@MainActor
public final class VulpraEngineRuntime: EngineRuntime {
    typealias ReadyResult = Result<EngineCapabilities, EngineFailure>

    private var handle: UnsafeMutableRawPointer?
    private var lifecycle = EngineRuntimeLifecycle()
    private var observers: [UUID: @MainActor (ReadyResult) -> Void] = [:]
    private var startupTimeoutTask: Task<Void, Never>?
    private let startupTimeoutNanoseconds: UInt64
    private var childProcesses = EngineChildProcessLifecycle()
    private var pendingPrefVerification: PrefVerificationState?
    private static let childLogger = Logger(
        subsystem: "com.vulpra.browser.engine-kit", category: "child-lifecycle"
    )
    private static let logger = Logger(
        subsystem: "com.vulpra.browser.engine-kit", category: "runtime"
    )

    public convenience init() {
        self.init(startupTimeoutNanoseconds: 20_000_000_000)
    }

    init(startupTimeoutNanoseconds: UInt64) {
        self.startupTimeoutNanoseconds = startupTimeoutNanoseconds
    }

    public var state: EngineRuntimeState { lifecycle.state }

    public func start(configuration: EngineRuntimeConfiguration) async throws -> EngineCapabilities {
        setLocale(configuration.localeIdentifier)
        guard ensureHandle() != nil else {
            throw EngineFailure(code: "abi-runtime-create", message: "Unable to create engine runtime",
                                isRecoverable: false)
        }
        if case .failed(let failure) = lifecycle.state, failure.isRecoverable {
            _ = lifecycle.begin()
        }
        if case .ready(let capabilities) = lifecycle.state { return capabilities }
        if case .failed(let failure) = lifecycle.state { throw failure }
        scheduleStartupTimeout()

        let identifier = UUID()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                observeReady(identifier: identifier) { result in
                    continuation.resume(with: result.mapError { $0 as Error })
                }
            }
        }, onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelStartObservation(identifier: identifier)
            }
        })
    }

    public func makeSession(configuration: EngineSessionConfiguration) -> any EngineSession {
        VulpraEngineSession(runtime: self, configuration: configuration)
    }

    private func observeReady(identifier: UUID, callback: @escaping @MainActor (ReadyResult) -> Void) {
        switch lifecycle.state {
        case .ready(let capabilities): callback(.success(capabilities))
        case .failed(let failure): callback(.failure(failure))
        case .stopped, .starting: observers[identifier] = callback
        }
    }

    func observeReady(_ callback: @escaping @MainActor (ReadyResult) -> Void) -> UUID? {
        switch lifecycle.state {
        case .ready(let capabilities): callback(.success(capabilities)); return nil
        case .failed(let failure): callback(.failure(failure)); return nil
        case .stopped, .starting:
            let identifier = UUID()
            observers[identifier] = callback
            return identifier
        }
    }

    func cancelReadyObservation(identifier: UUID?) {
        guard let identifier else { return }
        observers.removeValue(forKey: identifier)
    }

    private func cancelStartObservation(identifier: UUID) {
        guard let callback = observers.removeValue(forKey: identifier) else { return }
        callback(.failure(EngineFailure(
            code: "runtime-start-cancelled", message: "Engine startup was cancelled", isRecoverable: true
        )))
    }

    public func setLocale(_ identifier: String) {
        guard let handle = ensureHandle() else { return }
        dispatch(runtime: handle, type: "GeckoView:SetLocale", message: ["acceptLanguages": identifier])
    }

    public func clearData(_ options: EngineStorageClearOptions) {
        guard let handle = ensureHandle() else { return }
        dispatch(runtime: handle, type: "GeckoView:ClearData", message: ["flags": options.rawValue])
    }

    func runMain(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
        guard let handle = ensureHandle() else { return 70 }
        let result = engineABIRuntimeMain(handle, argc, argv)
        if result != 0 {
            markFailed(EngineFailure(
                code: "runtime-main-exit", message: "Engine main exited with status \(result)",
                isRecoverable: false
            ))
        }
        return result
    }

    func requiredHandle() -> UnsafeMutableRawPointer? { ensureHandle() }

    private func ensureHandle() -> UnsafeMutableRawPointer? {
        if let handle { return handle }
        let owner = EngineABIContext(self)
        let context = Unmanaged.passUnretained(owner).toOpaque()
        handle = withExtendedLifetime(owner) {
            engineABIRuntimeCreate(
                context, vulpraRuntimeEventHandler, vulpraRuntimeChildProcessHandler
            )
        }
        if handle == nil {
            markFailed(EngineFailure(
                code: "abi-runtime-create", message: "Unable to create engine runtime", isRecoverable: false
            ))
        } else {
            _ = lifecycle.begin()
        }
        return handle
    }

    /// RDD (Remote Data Decoder) child processes launch through the
    /// ExtensionKit path on iOS and can take several seconds to bootstrap under
    /// load (observed 5.8-7.6s on CI simulators). Upstream's 5s default
    /// startup timeout (`media.rdd-process.startup_timeout_ms`) races that
    /// bootstrap and kills the process before its IPC channel connects, which
    /// the child-lifecycle evidence correctly flags as terminated-before-
    /// outcome. Raise the timeout at runtime, before the first RDD launch,
    /// while keeping a fail-fast safety net. Evidence chain:
    /// docs/aegis/work/2026-07-29-vulpra-r0-trustworthy-engine-execution/30-rdd-startup-timeout-root-cause.md
    private static let rddProcessStartupTimeoutMilliseconds = 30_000

    private func applyRDDProcessStartupTimeout() {
        guard let handle = ensureHandle() else { return }
        let prefs: [[String: Any]] = [[
            "pref": "media.rdd-process.startup_timeout_ms",
            "type": 64, // nsIPrefBranch.PREF_INT (v5 PreferenceType cenum)
            "value": Self.rddProcessStartupTimeoutMilliseconds,
            "branch": "user",
        ]]
        dispatchPrefsWithVerification(handle: handle, prefs: prefs)
    }

    private func applyHTTPSOnlyMode() {
        guard let handle = ensureHandle() else { return }
        dispatch(runtime: handle, type: "GeckoView:Preferences:SetPref", message: [
            "prefs": [
                [
                    "pref": "dom.security.https_only_mode",
                    "type": 128, // nsIPrefBranch.PREF_BOOL (v5 PreferenceType cenum)
                    "value": true,
                    "branch": "user",
                ],
            ],
        ])
    }

    /// Tracking protection is configured globally by the App (all sessions share
    /// BrowserSettings), so per-session configuration can safely drive these
    /// global prefs: every open session sets the same effective value. If a
    /// future App introduces per-tab overrides, migrate to a runtime-level
    /// configuration instead of per-session SetPref.
    func applyTrackingProtectionPrefs(_ level: EngineTrackingProtectionLevel) {
        guard let handle = ensureHandle() else { return }
        let prefs: [[String: Any]] = [
            ["pref": "privacy.trackingprotection.enabled", "type": 128,
             "value": level != .off, "branch": "user"],
            ["pref": "privacy.trackingprotection.socialtracking.enabled", "type": 128,
             "value": level != .off, "branch": "user"],
            ["pref": "privacy.trackingprotection.fingerprinting.enabled", "type": 128,
             "value": level == .strict, "branch": "user"],
            ["pref": "privacy.trackingprotection.cryptomining.enabled", "type": 128,
             "value": level == .strict, "branch": "user"],
        ]
        dispatch(runtime: handle, type: "GeckoView:Preferences:SetPref", message: ["prefs": prefs])
    }

    /// Process-pool policy: bound the prelaunch Fission pool to 2 and the
    /// transient web-process cap to 4. Evidence: annex 63 (162-launch
    /// attribution) + annex 66 (GetMaxWebProcessCount at
    /// toolkit/xre/nsAppRunner.cpp:6491; the prelaunch pool bypasses the web
    /// cap while Fission autostarts, so fission.number is the real knob).
    /// PreallocatedProcessManager registers a Preferences observer
    /// (dom/ipc/PreallocatedProcessManager.cpp:127-128), so a runtime SetPref
    /// before the first navigation shrinks the pool immediately.
    private func applyProcessPoolPolicy() {
        guard let handle = ensureHandle() else { return }
        dispatch(runtime: handle, type: "GeckoView:Preferences:SetPref", message: [
            "prefs": [
                [
                    "pref": "dom.ipc.processPrelaunch.fission.number",
                    "type": 64, // nsIPrefBranch.PREF_INT (v5 PreferenceType cenum)
                    "value": 2,
                    "branch": "user",
                ],
                [
                    "pref": "dom.ipc.processCount",
                    "type": 64, // nsIPrefBranch.PREF_INT (v5 PreferenceType cenum)
                    "value": 4,
                    "branch": "user",
                ],
            ],
        ])
    }

    private func markReady() {
        applyRDDProcessStartupTimeout()
        applyHTTPSOnlyMode()
        applyProcessPoolPolicy()
        // No-op when the runtime already reached a terminal state: observers
        // must not be completed as success after a non-recoverable failure.
        guard lifecycle.becomeReady(Self.capabilities) else { return }
        // A2 cold-start anchor: single public-privacy line consumed by
        // run-simulator-cold-start.sh to measure launch -> engine ready.
        Self.logger.notice("Engine runtime ready")
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil
        completeObservers(.success(Self.capabilities))
    }

    private func markFailed(_ failure: EngineFailure) {
        lifecycle.fail(failure)
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil
        completeObservers(.failure(failure))
    }

    private func completeObservers(_ result: ReadyResult) {
        let pending = observers.values
        observers.removeAll()
        pending.forEach { $0(result) }
    }

    private func scheduleStartupTimeout() {
        guard startupTimeoutTask == nil else { return }
        let delay = startupTimeoutNanoseconds
        startupTimeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard let self, case .starting = self.lifecycle.state else { return }
            let openLaunches = self.childProcesses.openLaunchIDs.map(String.init).joined(separator: ",")
            self.markFailed(EngineFailure(
                code: "engine-bootstrap-timeout",
                message: "Engine bootstrap timed out; open child launches: [\(openLaunches)]",
                isRecoverable: true
            ))
        }
    }

    private func dispatch(runtime: UnsafeMutableRawPointer, type: String, message: [String: Any]) {
        let name = type as NSString
        let payload = message as NSDictionary
        withExtendedLifetime(name) {
            withExtendedLifetime(payload) {
                engineABIRuntimeDispatch(runtime, engineABIPointer(name), engineABIPointer(payload))
            }
        }
    }

    /// Dispatches a GeckoView:Preferences:SetPref request with a callback that
    /// verifies the Gecko side actually handled it (GeckoViewPreferences.sys.mjs
    /// replies `{prefs: [{pref, isSet}]}`). The response is recorded as
    /// rdd-timeout-pref-set evidence; a 10 s watchdog covers the not-delivered
    /// case. The SetPref itself is fire-and-forget for readiness ordering.
    private func dispatchPrefsWithVerification(handle: UnsafeMutableRawPointer, prefs: [[String: Any]]) {
        let state = PrefVerificationState(
            runtime: self,
            pref: "media.rdd-process.startup_timeout_ms",
            expectedValue: Self.rddProcessStartupTimeoutMilliseconds
        )
        pendingPrefVerification = state
        let context = Unmanaged.passUnretained(state).toOpaque()
        dispatchWithCallback(
            runtime: handle, type: "GeckoView:Preferences:SetPref",
            message: ["prefs": prefs], context: context,
            callback: vulpraPrefSetCallbackHandler
        )
        schedulePrefVerificationWatchdog(state)
    }

    private func dispatchWithCallback(
        runtime: UnsafeMutableRawPointer, type: String, message: [String: Any],
        context: UnsafeMutableRawPointer?, callback: EngineABICallbackHandler?
    ) {
        let name = type as NSString
        let payload = message as NSDictionary
        withExtendedLifetime(name) {
            withExtendedLifetime(payload) {
                engineABIRuntimeDispatchWithCallback(
                    runtime, engineABIPointer(name), engineABIPointer(payload),
                    context, callback
                )
            }
        }
    }

    private func schedulePrefVerificationWatchdog(_ state: PrefVerificationState) {
        Task { @MainActor [weak state] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let state else { return }
            if state.consume() {
                Self.logger.error(
                    "rdd-timeout-pref-set verification timed out pref=\(state.pref, privacy: .public) expected=\(state.expectedValue)"
                )
            }
        }
    }

    fileprivate func handlePrefSetVerification(_ state: PrefVerificationState, response: Any?, error: String?) {
        guard state.consume() else { return }
        if let error {
            Self.logger.error("rdd-timeout-pref-set error=\(error, privacy: .public)")
            return
        }
        guard let prefs = (response as? [String: Any])?["prefs"] as? [[String: Any]],
              let first = prefs.first, let isSet = first["isSet"] as? Bool else {
            Self.logger.error("rdd-timeout-pref-set unexpected response=\(String(describing: response))")
            return
        }
        if isSet {
            Self.logger.notice(
                "rdd-timeout-pref-set verified pref=\(state.pref, privacy: .public) expected=\(state.expectedValue) isSet=true"
            )
        } else {
            Self.logger.error("rdd-timeout-pref-set isSet=false pref=\(state.pref, privacy: .public)")
        }
    }

    fileprivate func handle(type: String, message: Any?, callback: EngineABICallbackLease?) {
        switch type {
        case "Vulpra:RuntimeReady": markReady()
        default: break
        }
        resolve(callback, value: NSNull())
    }

    fileprivate func handleChildProcess(_ event: EngineChildProcessEvent) {
        let failure = childProcesses.accept(event)
        let safeReason = event.reason.flatMap { reason -> String? in
            let lowered = reason.lowercased()
            return reason.utf8.count <= 160 && !lowered.contains("://") && !lowered.contains("www.")
                ? reason : nil
        }
        Self.childLogger.notice(
            "launch=\(event.launchID) child=\(event.childID) type=\(event.processType, privacy: .public) pid=\(event.processIdentifier ?? 0) stage=\(event.stage.rawValue) monotonic_ns=\(event.monotonicTimestampNanoseconds) failure=\(event.failureCode.rawValue) reason=\(safeReason ?? "none", privacy: .public)"
        )
        guard let failure else { return }
        if case .starting = lifecycle.state {
            markFailed(failure)
        }
    }

    fileprivate func handleUnknownChildProcessStage(_ rawStage: Int32, launchID: UInt64) {
        let failure = childProcesses.rejectUnknownStage(rawStage, launchID: launchID)
        if case .starting = lifecycle.state {
            markFailed(failure)
        }
    }

    static var capabilities: EngineCapabilities {
        let rawProfile = Bundle.main.object(forInfoDictionaryKey: "VulpraDistributionProfile") as? String
        let profile = EngineDistributionProfile(rawValue: rawProfile ?? "") ?? .externalSigning
        return EngineCapabilities(
            executionMode: .interpreter, supportsPrompts: true, supportsPermissions: true,
            supportsDownloads: true, supportsStorage: true, supportsExtensions: false,
            supportsPictureInPicture: false, supportsAutofill: false,
            supportsBackgroundMedia: true,
            distributionProfile: profile, sandboxAuthority: .extensionKit,
            usesPrivateProcessTransport: true
        )
    }
}

private let vulpraRuntimeEventHandler: EngineABIEventHandler = { context, type, message, callback in
    let lease = takeCallback(callback)
    guard let context else { lease?.cancel("runtime unavailable"); return }
    let owner = Unmanaged<EngineABIContext<VulpraEngineRuntime>>.fromOpaque(context).takeUnretainedValue()
    let runtime = owner.value
    let eventType = bridgeString(type)
    let eventMessage = bridgeObject(message)
    DispatchQueue.main.async {
        runtime.handle(type: eventType, message: eventMessage, callback: lease)
    }
}

private let vulpraPrefSetCallbackHandler: EngineABICallbackHandler = { context, response, error in
    guard let context else { return }
    let state = Unmanaged<PrefVerificationState>.fromOpaque(context).takeUnretainedValue()
    let responseObject = response.map(bridgeObject)
    let errorString = error.map(bridgeString)
    DispatchQueue.main.async {
        state.runtime?.handlePrefSetVerification(state, response: responseObject, error: errorString)
    }
}

private let vulpraRuntimeChildProcessHandler: EngineABIChildProcessHandler = {
    context, launchID, childID, pid, processType, rawStage, timestamp, rawFailure, reason in
    guard let context else { return }
    let owner = Unmanaged<EngineABIContext<VulpraEngineRuntime>>
        .fromOpaque(context).takeUnretainedValue()
    let runtime = owner.value
    let processTypeValue = bridgeString(processType)
    let reasonValue = reason.map(bridgeString)
    guard let stage = EngineChildProcessStage(rawValue: rawStage),
          let failureCode = EngineChildProcessFailureCode(rawValue: rawFailure) else {
        DispatchQueue.main.async {
            runtime.handleUnknownChildProcessStage(rawStage, launchID: launchID)
        }
        return
    }
    let event = EngineChildProcessEvent(
        launchID: launchID,
        childID: childID,
        processIdentifier: pid == 0 ? nil : pid,
        processType: processTypeValue,
        stage: stage,
        monotonicTimestampNanoseconds: timestamp,
        failureCode: failureCode,
        reason: reasonValue
    )
    DispatchQueue.main.async {
        runtime.handleChildProcess(event)
    }
}

/// Tracks a single GeckoView:Preferences:SetPref verification. The runtime
/// keeps the last pending state alive; consume() is idempotent and only runs
/// on the main actor (callback handler + watchdog), so no locking is needed.
private final class PrefVerificationState {
    weak var runtime: VulpraEngineRuntime?
    let pref: String
    let expectedValue: Int
    private var consumed = false

    init(runtime: VulpraEngineRuntime, pref: String, expectedValue: Int) {
        self.runtime = runtime
        self.pref = pref
        self.expectedValue = expectedValue
    }

    /// Returns true only for the first consumer.
    func consume() -> Bool {
        if consumed { return false }
        consumed = true
        return true
    }
}

public enum VulpraEngine {
    @MainActor
    public static let runtime = VulpraEngineRuntime()
}

@discardableResult
@MainActor
public func VulpraEngineApplicationMain(
    argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> Int32 {
    VulpraEngine.runtime.runMain(argc: argc, argv: argv)
}

func bridgeString(_ pointer: UnsafeRawPointer) -> String {
    Unmanaged<NSString>.fromOpaque(UnsafeMutableRawPointer(mutating: pointer)).takeUnretainedValue() as String
}

func bridgeObject(_ pointer: UnsafeRawPointer?) -> Any? {
    guard let pointer else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(UnsafeMutableRawPointer(mutating: pointer)).takeUnretainedValue()
}

func resolve(_ callback: EngineABICallbackLease?, value: AnyObject, error: Bool = false) {
    callback?.resolve(value, isError: error)
}
