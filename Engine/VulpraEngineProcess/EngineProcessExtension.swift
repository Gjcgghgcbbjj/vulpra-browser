import Foundation
import os
import VulpraEngineKit

// MARK: - Real-device JIT capability probe (diagnostic)
// The engine's web JS (and the Speedometer benchmark) runs inside this
// appex, i.e. a Gecko child process instance. Whether JIT actually works
// depends on THIS process's CS_DEBUGGED state and on its ability to reserve
// executable memory with mmap(MAP_JIT) - not on the main app's state, which
// is what the start page probe used to report. Every extension launch runs
// this self-probe and publishes the result to a well-known file so the App
// can render it on the start page without any shell access.
private enum VulpraAppexJITProbe {
    static let primaryPath = "/var/mobile/Documents/vulpra-jit-probe.json"
    static let fallbackPath = "/tmp/vulpra-jit-probe.json"
    static func run(processType: String?) {
#if !targetEnvironment(simulator)
        var flags: UInt32 = 0
        let csopsErrno: Int32
        let csopsResult = vulpraAppexCsops(getpid(), 0, &flags, MemoryLayout<UInt32>.size)
        csopsErrno = errno
        var mapJIT = "not-tested"
        var execProtect = "not-tested"
        let size = 0x4000
        let page = mmap(nil, size, PROT_READ | PROT_WRITE,
                        MAP_PRIVATE | MAP_ANONYMOUS | MAP_JIT, -1, 0)
        if page == MAP_FAILED {
            mapJIT = "fail(errno=\(errno))"
        } else {
            mapJIT = "ok"
            if mprotect(page, size, PROT_READ | PROT_EXEC) == 0 {
                execProtect = "ok"
            } else {
                execProtect = "fail(errno=\(errno))"
            }
            munmap(page, size)
        }
        let launches = incrementLaunches()
        let debugged = (flags & (0x10000000 | 0x00000800)) != 0
        let payload: [String: Any] = [
            "pid": getpid(),
            "processType": processType ?? "unknown",
            "csops": csopsResult == 0 ? "ok" : "err(\(csopsErrno))",
            "flags": String(format: "0x%08X", flags),
            "debugged": debugged,
            "mapjit": mapJIT,
            "mprotect": execProtect,
            "launches": launches,
            "timestamp": Date().timeIntervalSince1970,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: primaryPath))
            try? data.write(to: URL(fileURLWithPath: fallbackPath))
        }
#endif
    }
    private static func incrementLaunches() -> Int {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: primaryPath)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let previous = object["launches"] as? Int else {
            return 1
        }
        return previous + 1
    }
}
#if !targetEnvironment(simulator)
@_silgen_name("csops")
private func vulpraAppexCsops(_ pid: Int32, _ ops: UInt32,
                              _ useraddr: UnsafeMutableRawPointer?,
                              _ usersize: Int) -> Int32
#endif
@objc private protocol EngineBootstrapPing {
    func ping()
}
@objc(VulpraEngineProcessMain)
final class VulpraEngineProcessMain: NSObject, NSExtensionRequestHandling {
    private static let logger = Logger(subsystem: "com.vulpra.browser.engine-process", category: "bootstrap")
    private struct RequestOwner {
        let connection: NSXPCConnection
        let context: NSExtensionContext
        let launchID: UInt64
        let childID: Int32
    }
    private static var requests: [ObjectIdentifier: RequestOwner] = [:]
    func beginRequest(with context: NSExtensionContext) {
        VulpraAppexJITProbe.run(processType: nil)
        DispatchQueue.main.async {
            do {
                try Self.start(context: context)
            } catch {
                Self.logger.error(
                    "Vulpra Engine Process request failed: \(error.localizedDescription, privacy: .public)"
                )
                context.cancelRequest(withError: error)
            }
        }
    }
    private static func start(context: NSExtensionContext) throws {
        guard let input = context.inputItems.first as? NSExtensionItem else {
            throw NSError(
                domain: "Vulpra.EngineProcess", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing process extension input"]
            )
        }
        let request = try EngineProcessRequest(userInfo: input.userInfo)
        logger.notice(
            "Engine process request received launch=\(request.launchID) child=\(request.childID) type=\(request.processType, privacy: .public)"
        )
        let connection = NSXPCConnection(listenerEndpoint: request.endpoint)
        let identifier = ObjectIdentifier(connection)
        connection.remoteObjectInterface = NSXPCInterface(with: EngineBootstrapPing.self)
        connection.interruptionHandler = { Self.finish(identifier: identifier) }
        connection.invalidationHandler = { Self.finish(identifier: identifier) }
        connection.resume()
        do {
            try VulpraEngineProcessHost.start(connection: connection)
        } catch {
            connection.invalidate()
            throw error
        }
        logger.notice(
            "Engine process connected launch=\(request.launchID) child=\(request.childID)"
        )
        requests[identifier] = RequestOwner(
            connection: connection,
            context: context,
            launchID: request.launchID,
            childID: request.childID
        )
        (connection.remoteObjectProxyWithErrorHandler { _ in } as? EngineBootstrapPing)?.ping()
    }
    private static func finish(identifier: ObjectIdentifier) {
        DispatchQueue.main.async {
            guard let request = requests.removeValue(forKey: identifier) else { return }
            request.context.completeRequest(returningItems: nil)
            logger.notice(
                "Engine process connection released launch=\(request.launchID) child=\(request.childID)"
            )
        }
    }
}
