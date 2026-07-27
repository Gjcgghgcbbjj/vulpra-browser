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
            trackingProtection: true
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
