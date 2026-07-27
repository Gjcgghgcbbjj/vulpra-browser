import Foundation

public struct EngineSessionID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct EngineFailure: Error, Equatable, Sendable {
    public let code: String
    public let message: String
    public let isRecoverable: Bool

    public init(code: String, message: String, isRecoverable: Bool) {
        self.code = code
        self.message = message
        self.isRecoverable = isRecoverable
    }
}

public struct EngineNavigationEvent: Equatable, Sendable {
    public let sessionID: EngineSessionID
    public let url: URL?
    public let title: String
    public let canGoBack: Bool
    public let canGoForward: Bool

    public init(
        sessionID: EngineSessionID,
        url: URL?,
        title: String,
        canGoBack: Bool,
        canGoForward: Bool
    ) {
        self.sessionID = sessionID
        self.url = url
        self.title = title
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }
}

public enum EngineProgressEvent: Equatable, Sendable {
    case started(sessionID: EngineSessionID, url: URL?)
    case changed(sessionID: EngineSessionID, fraction: Double)
    case completed(sessionID: EngineSessionID, succeeded: Bool)
    case failed(sessionID: EngineSessionID, failure: EngineFailure)
}

public enum EngineTerminationReason: String, Codable, Sendable {
    case processExited
    case killed
    case invalidState
    case unknown
}

@MainActor
public protocol EngineNavigationObserver: AnyObject {
    func engineSessionDidOpen(_ id: EngineSessionID)
    func engineSession(_ id: EngineSessionID, didUpdate event: EngineNavigationEvent)
    func engineSessionDidRequestClose(_ id: EngineSessionID)
    func engineSession(_ id: EngineSessionID, requestedNewSessionFor url: URL, windowID: String) -> Bool
}

@MainActor
public protocol EngineProgressObserver: AnyObject {
    func engineSession(_ id: EngineSessionID, didUpdate event: EngineProgressEvent)
    func engineSession(_ id: EngineSessionID, didTerminate reason: EngineTerminationReason)
}
