#if DEBUG
import Foundation
import Network
import os

/// Debug-only loopback hook used by the Simulator R0 harness.
/// The iOS 26 Simulator blocks `simctl openurl` custom-scheme delivery behind a
/// SpringBoard "Open in" confirmation prompt that cannot be tapped headlessly.
/// This server gives the reusable R0 harness a deterministic, auditable way to
/// deliver the same deep-link URL to the already-running browser while keeping
/// the measured navigation on the real `BrowserViewController.open` / EngineKit
/// load path.
final class GateDispatchServer {
    private let logger = Logger(subsystem: "com.vulpra.browser", category: "gate")
    private let listener: NWListener
    private let onOpen: (URL) -> Void
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private let queue = DispatchQueue(label: "com.vulpra.browser.gate.dispatch")

    init?(portText: String, onOpen: @escaping (URL) -> Void) {
        guard let value = UInt16(portText), let port = NWEndpoint.Port(rawValue: value) else {
            return nil
        }
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredInterfaceType = .loopback
        guard let listener = try? NWListener(using: parameters, on: port) else {
            return nil
        }
        self.listener = listener
        self.onOpen = onOpen
    }

    func start() {
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                let port = self.listener.port?.rawValue ?? 0
                self.logger.notice("Vulpra gate dispatch server listening on port \(port)")
            case .failed(let error):
                self.logger.error("Vulpra gate dispatch server failed: \(error.localizedDescription, privacy: .public)")
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.listener.cancel()
            for connection in self.connections.values {
                connection.cancel()
            }
            self.connections.removeAll()
        }
    }

    private func accept(_ connection: NWConnection) {
        queue.async { [weak self] in
            guard let self else { return }
            self.connections[ObjectIdentifier(connection)] = connection
            connection.stateUpdateHandler = { [weak self] state in
                guard case .failed(let error) = state else { return }
                self?.logger.error("Vulpra gate dispatch connection failed: \(error.localizedDescription, privacy: .public)")
                self?.close(connection)
            }
            connection.start(queue: self.queue)
            self.receive(on: connection)
        }
    }

    private func receive(on connection: NWConnection, accumulator: Data = Data()) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var received = accumulator
            if let data {
                received.append(data)
            }
            let text = String(data: received, encoding: .utf8) ?? ""
            if self.isCompleteRequest(text) {
                self.handle(request: text, on: connection)
                return
            }
            if let error {
                self.logger.error("Vulpra gate dispatch receive error: \(error.localizedDescription, privacy: .public)")
                self.close(connection)
                return
            }
            if isComplete {
                self.handle(request: text, on: connection)
                return
            }
            self.receive(on: connection, accumulator: received)
        }
    }

    private func isCompleteRequest(_ text: String) -> Bool {
        guard let headerEnd = text.range(of: "\r\n\r\n") else {
            return false
        }
        let head = text[..<headerEnd.lowerBound]
        let body = text[headerEnd.upperBound...]
        guard let contentLength = head
            .split(separator: "\r\n")
            .first(where: { $0.lowercased().hasPrefix("content-length:") })
            .flatMap({ String($0.split(separator: ":").last ?? "").trimmingCharacters(in: .whitespaces) })
            .flatMap({ Int($0) })
        else {
            return true
        }
        return body.count >= contentLength
    }

    private func handle(request: String, on connection: NWConnection) {
        if request.hasPrefix("GET /ping") {
            self.respond("ok", code: 200, on: connection)
            return
        }
        let body = request
            .components(separatedBy: "\r\n\r\n")
            .dropFirst()
            .joined(separator: "\r\n\r\n")
        guard !body.isEmpty,
              let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let value = (dictionary["deepLink"] as? String) ?? (dictionary["url"] as? String),
              let url = URL(string: value)
        else {
            self.respond("bad request", code: 400, on: connection)
            return
        }
        self.logger.notice("Vulpra gate dispatch opened: \(value, privacy: .public)")
        // EngineKit / Gecko dispatch (AutoJSAPI) is main-thread bound; hop off the
        // loopback accept queue before opening so navigation uses the same thread
        // as scene URL contexts.
        let deepLink = url
        DispatchQueue.main.async { [weak self] in
            self?.onOpen(deepLink)
        }
        self.respond("ok", code: 200, on: connection)
    }

    private func respond(_ bodyText: String, code: Int, on connection: NWConnection) {
        let body = bodyText.data(using: .utf8) ?? Data()
        let reason = code == 200 ? "OK" : "Bad Request"
        let head = "HTTP/1.1 \(code) \(reason)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var payload = head.data(using: .utf8) ?? Data()
        payload.append(body)
        queue.async { [weak self] in
            connection.send(content: payload, completion: .contentProcessed { _ in
                self?.close(connection)
            })
        }
    }

    private func close(_ connection: NWConnection) {
        queue.async { [weak self] in
            self?.connections.removeValue(forKey: ObjectIdentifier(connection))
            connection.cancel()
        }
    }
}
#endif
