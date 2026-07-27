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
    }
    private static var requests: [ObjectIdentifier: RequestOwner] = [:]

    func beginRequest(with context: NSExtensionContext) {
        Self.logger.notice("Vulpra Engine Process request received")
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
        guard let endpoint = input.userInfo?["VulpraXPCListenerEndpoint"] as? NSXPCListenerEndpoint else {
            throw NSError(
                domain: "Vulpra.EngineProcess", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing native process listener endpoint"]
            )
        }
        let connection = NSXPCConnection(listenerEndpoint: endpoint)
        let identifier = ObjectIdentifier(connection)
        connection.remoteObjectInterface = NSXPCInterface(with: EngineBootstrapPing.self)
        connection.interruptionHandler = { Self.finish(identifier: identifier) }
        connection.invalidationHandler = { Self.finish(identifier: identifier) }
        connection.resume()
        guard VulpraEngineProcessHost.start(connection: connection) else {
            connection.invalidate()
            throw NSError(
                domain: "Vulpra.EngineProcess", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to start engine child process"]
            )
        }
        logger.notice("Vulpra Engine Process connected")
        requests[identifier] = RequestOwner(connection: connection, context: context)
        (connection.remoteObjectProxyWithErrorHandler { _ in } as? EngineBootstrapPing)?.ping()
    }

    private static func finish(identifier: ObjectIdentifier) {
        DispatchQueue.main.async {
            guard let request = requests.removeValue(forKey: identifier) else { return }
            request.context.completeRequest(returningItems: nil)
            logger.notice("Vulpra Engine Process connection released")
        }
    }
}
