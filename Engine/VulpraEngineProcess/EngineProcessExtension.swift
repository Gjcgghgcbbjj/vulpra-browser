import Foundation
import os
import VulpraEngineKit

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
