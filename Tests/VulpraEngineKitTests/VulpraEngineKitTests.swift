import XCTest
@testable import VulpraEngineKit

@MainActor
final class VulpraEngineKitTests: XCTestCase {
    func testRuntimeStartsStopped() async {
        let runtime = VulpraEngineRuntime()

        let state = await runtime.state
        XCTAssertEqual(state, .stopped)
    }

    func testRuntimeCreatesProtocolSessionWithRequestedConfiguration() async {
        let runtime: any EngineRuntime = VulpraEngineRuntime()
        let configuration = EngineSessionConfiguration(
            isPrivate: true,
            userAgentMode: .desktop,
            pageZoom: 1.25,
            trackingProtection: .standard
        )

        let session = runtime.makeSession(configuration: configuration)

        let actual = await session.configuration
        XCTAssertEqual(actual, configuration)
    }

    func testCallbackLeaseResolvesOnlyOnce() {
        let recorder = CallbackRecorder()
        let lease = EngineABICallbackLease { value, isError in
            recorder.append(value: value, isError: isError)
        }

        lease.resolve(NSNumber(value: true))
        lease.cancel()

        XCTAssertEqual(recorder.count, 1)
        XCTAssertEqual(recorder.lastBoolean, true)
        XCTAssertEqual(recorder.lastWasError, false)
    }

    func testCallbackLeaseCancelsWhenAbandoned() {
        let recorder = CallbackRecorder()
        var lease: EngineABICallbackLease? = EngineABICallbackLease { value, isError in
            recorder.append(value: value, isError: isError)
        }

        lease = nil

        XCTAssertNil(lease)
        XCTAssertEqual(recorder.count, 1)
        XCTAssertEqual(recorder.lastWasError, true)
    }

    func testRuntimeLifecycleCanRetryRecoverableFailure() {
        var lifecycle = EngineRuntimeLifecycle()
        let failure = EngineFailure(code: "timeout", message: "timeout", isRecoverable: true)

        XCTAssertTrue(lifecycle.begin())
        lifecycle.fail(failure)
        XCTAssertEqual(lifecycle.state, .failed(failure))
        XCTAssertTrue(lifecycle.begin())
        XCTAssertEqual(lifecycle.state, .starting)
        lifecycle.becomeReady(Self.capabilities)
        XCTAssertEqual(lifecycle.state, .ready(Self.capabilities))
    }

    func testRuntimeLifecycleReadyOnlyFailsOnNonRecoverableExit() {
        var lifecycle = EngineRuntimeLifecycle()
        let fatal = EngineFailure(
            code: "runtime-main-exit", message: "Engine main exited", isRecoverable: false
        )
        let transient = EngineFailure(code: "busy", message: "transient", isRecoverable: true)

        _ = lifecycle.begin()
        lifecycle.becomeReady(Self.capabilities)
        XCTAssertEqual(lifecycle.state, .ready(Self.capabilities))

        lifecycle.fail(transient)
        XCTAssertEqual(lifecycle.state, .ready(Self.capabilities))

        lifecycle.fail(fatal)
        XCTAssertEqual(lifecycle.state, .failed(fatal))
        XCTAssertFalse(lifecycle.begin())
    }

    func testRuntimeLifecycleTerminalFailureIsNotResurrectedByLateReady() {
        var lifecycle = EngineRuntimeLifecycle()
        let fatal = EngineFailure(
            code: "runtime-main-exit", message: "Engine main exited", isRecoverable: false
        )

        XCTAssertTrue(lifecycle.begin())
        lifecycle.fail(fatal)
        XCTAssertEqual(lifecycle.state, .failed(fatal))

        // Late Vulpra:RuntimeReady must NOT resurrect the terminal failure.
        XCTAssertFalse(lifecycle.becomeReady(Self.capabilities))
        XCTAssertEqual(lifecycle.state, .failed(fatal))
        XCTAssertFalse(lifecycle.begin())
    }

    func testRuntimeLifecycleSecondFailureDoesNotReplaceTerminalFailure() {
        var lifecycle = EngineRuntimeLifecycle()
        let fatal = EngineFailure(
            code: "runtime-main-exit", message: "Engine main exited", isRecoverable: false
        )
        let transient = EngineFailure(code: "busy", message: "busy", isRecoverable: true)

        XCTAssertTrue(lifecycle.begin())
        lifecycle.fail(fatal)
        XCTAssertEqual(lifecycle.state, .failed(fatal))

        // A later recoverable failure must not mask the terminal reason.
        lifecycle.fail(transient)
        XCTAssertEqual(lifecycle.state, .failed(fatal))
    }

    func testSessionLifecycleClosesAfterFailedOpenAndRetry() {
        var lifecycle = EngineSessionLifecycle()
        let failure = EngineFailure(code: "open", message: "open", isRecoverable: true)

        XCTAssertTrue(lifecycle.beginOpen())
        lifecycle.fail(failure)
        XCTAssertTrue(lifecycle.beginOpen())
        XCTAssertTrue(lifecycle.becomeOpen())
        XCTAssertTrue(lifecycle.beginClose())
        lifecycle.finishClose()
        XCTAssertEqual(lifecycle.state, .closed)
    }

    func testNavigationLoadErrorPreservesURLAndCoalescesFailedPageStop() {
        let runtime = VulpraEngineRuntime()
        let session = VulpraEngineSession(runtime: runtime, configuration: .init(
            isPrivate: false, userAgentMode: .mobile, pageZoom: 1
        ))
        let recorder = SessionEventRecorder()
        session.navigationObserver = recorder
        session.progressObserver = recorder

        session.handle(type: "GeckoView:OnLoadError", message: [
            "uri": "https://unavailable.example/", "error": -1,
            "errorModule": 6, "errorClass": 2,
        ], callback: nil)
        session.handle(type: "GeckoView:PageStop", message: ["success": false], callback: nil)

        XCTAssertEqual(recorder.lastURL, URL(string: "https://unavailable.example/"))
        XCTAssertEqual(recorder.failures.count, 1)
        XCTAssertEqual(recorder.failures.first?.code, "navigation-failed")
    }

    func testChildProcessLifecycleAcceptsSuccessfulConnection() {
        var lifecycle = EngineChildProcessLifecycle()
        XCTAssertNil(lifecycle.accept(childEvent(stage: .requested, timestamp: 1)))
        XCTAssertNil(lifecycle.accept(childEvent(stage: .extensionConnected, timestamp: 2)))
        XCTAssertNil(lifecycle.accept(childEvent(
            stage: .bootstrapAcknowledged, timestamp: 3, pid: 321
        )))
        XCTAssertNil(lifecycle.accept(childEvent(stage: .ipcConnected, timestamp: 4, pid: 321)))
        XCTAssertEqual(lifecycle.record(for: 1)?.outcome, .connected)
        XCTAssertEqual(lifecycle.openLaunchIDs, [1])
    }

    func testChildProcessLifecycleAcceptsFailureBeforeConnection() {
        var lifecycle = EngineChildProcessLifecycle()
        XCTAssertNil(lifecycle.accept(childEvent(stage: .requested, timestamp: 1)))
        let failure = lifecycle.accept(childEvent(
            stage: .failed, timestamp: 2, failure: .extensionStart, reason: "extension-start"
        ))
        XCTAssertEqual(failure?.code, "engine-child-extension-start")
        XCTAssertEqual(lifecycle.record(for: 1)?.outcome, .failed(.extensionStart))
    }

    func testChildProcessLifecycleRejectsDuplicateEvent() {
        var lifecycle = EngineChildProcessLifecycle()
        XCTAssertNil(lifecycle.accept(childEvent(stage: .requested, timestamp: 1)))
        let failure = lifecycle.accept(childEvent(stage: .requested, timestamp: 2))
        XCTAssertEqual(failure?.code, "engine-child-invalid-transition")
        XCTAssertEqual(lifecycle.events.count, 1)
    }

    func testChildProcessLifecycleRejectsStageAndTimestampRegression() {
        var lifecycle = EngineChildProcessLifecycle()
        XCTAssertNil(lifecycle.accept(childEvent(stage: .requested, timestamp: 10)))
        XCTAssertEqual(
            lifecycle.accept(childEvent(stage: .extensionConnected, timestamp: 9))?.code,
            "engine-child-invalid-transition"
        )
        XCTAssertEqual(
            lifecycle.accept(childEvent(stage: .bootstrapAcknowledged, timestamp: 11))?.code,
            "engine-child-invalid-transition"
        )
    }

    func testChildProcessLifecycleClosesConnectedTerminationOnce() {
        var lifecycle = EngineChildProcessLifecycle()
        for event in [
            childEvent(stage: .requested, timestamp: 1),
            childEvent(stage: .extensionConnected, timestamp: 2),
            childEvent(stage: .bootstrapAcknowledged, timestamp: 3, pid: 321),
            childEvent(stage: .ipcConnected, timestamp: 4, pid: 321),
        ] {
            XCTAssertNil(lifecycle.accept(event))
        }
        XCTAssertEqual(
            lifecycle.accept(childEvent(stage: .terminated, timestamp: 5, pid: 321))?.code,
            "engine-child-terminated"
        )
        XCTAssertEqual(lifecycle.record(for: 1)?.outcome, .connected)
        XCTAssertTrue(lifecycle.openLaunchIDs.isEmpty)
        XCTAssertEqual(
            lifecycle.accept(childEvent(stage: .terminated, timestamp: 6, pid: 321))?.code,
            "engine-child-invalid-transition"
        )
    }

    func testChildProcessLifecycleRejectsUnknownStage() {
        var lifecycle = EngineChildProcessLifecycle()
        let failure = lifecycle.rejectUnknownStage(99, launchID: 1)
        XCTAssertEqual(failure.code, "engine-child-invalid-transition")
        XCTAssertEqual(lifecycle.failures.count, 1)
    }

    private func childEvent(
        stage: EngineChildProcessStage,
        timestamp: UInt64,
        pid: Int32? = nil,
        failure: EngineChildProcessFailureCode = .none,
        reason: String? = nil
    ) -> EngineChildProcessEvent {
        EngineChildProcessEvent(
            launchID: 1,
            childID: 7,
            processIdentifier: pid,
            processType: "content",
            stage: stage,
            monotonicTimestampNanoseconds: timestamp,
            failureCode: failure,
            reason: reason
        )
    }

    private static let capabilities = EngineCapabilities(
        executionMode: .interpreter,
        supportsPrompts: true,
        supportsPermissions: true,
        supportsDownloads: true,
        supportsStorage: true,
        supportsExtensions: false,
        supportsPictureInPicture: false,
        supportsBackgroundMedia: true,
        distributionProfile: .externalSigning,
        sandboxAuthority: .extensionKit,
        usesPrivateProcessTransport: true
    )
}

@MainActor
private final class SessionEventRecorder: EngineNavigationObserver, EngineProgressObserver {
    var lastURL: URL?
    var failures: [EngineFailure] = []

    func engineSessionDidOpen(_ id: EngineSessionID) {}
    func engineSession(_ id: EngineSessionID, didUpdate event: EngineNavigationEvent) { lastURL = event.url }
    func engineSessionDidRequestClose(_ id: EngineSessionID) {}
    func engineSession(_ id: EngineSessionID, requestedNewSessionFor url: URL, windowID: String) -> Bool { false }
    func engineSession(_ id: EngineSessionID, didUpdate event: EngineProgressEvent) {
        if case .failed(_, let failure) = event { failures.append(failure) }
    }
    func engineSession(_ id: EngineSessionID, didTerminate reason: EngineTerminationReason) {}
}

private final class CallbackRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [(AnyObject, Bool)] = []

    var count: Int { withLock { values.count } }
    var lastBoolean: Bool? { withLock { (values.last?.0 as? NSNumber)?.boolValue } }
    var lastWasError: Bool? { withLock { values.last?.1 } }

    func append(value: AnyObject, isError: Bool) {
        withLock { values.append((value, isError)) }
    }

    private func withLock<Value>(_ body: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
