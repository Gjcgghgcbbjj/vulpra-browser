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
    private static let childLogger = Logger(
        subsystem: "com.vulpra.browser.engine-kit", category: "child-lifecycle"
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

    private func markReady() {
        lifecycle.becomeReady(Self.capabilities)
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
            supportsPictureInPicture: false, supportsBackgroundMedia: true,
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
