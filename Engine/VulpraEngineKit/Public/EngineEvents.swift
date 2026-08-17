import Foundation

public struct EngineSessionID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct EngineNavigationState: Equatable, Sendable {
    public let url: URL?
    public let title: String
    public let canGoBack: Bool
    public let canGoForward: Bool

    public init(url: URL?, title: String = "", canGoBack: Bool = false,
                canGoForward: Bool = false) {
        self.url = url
        self.title = title
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
    }
}

public enum EngineLoadState: Equatable, Sendable {
    case started(URL?)
    case progress(Double)
    case finished(success: Bool)
    case crashed
}

public struct EngineNewSessionRequest: Sendable {
    public let url: URL?
    public let privateMode: Bool

    public init(url: URL?, privateMode: Bool) {
        self.url = url
        self.privateMode = privateMode
    }
}

public protocol EngineNavigationObserver: AnyObject {
    func engineSession(_ session: any EngineSession,
                       didUpdate state: EngineNavigationState)
    func engineSession(_ session: any EngineSession,
                       requestedNewSession request: EngineNewSessionRequest) -> (any EngineSession)?
}

public protocol EngineProgressObserver: AnyObject {
    func engineSession(_ session: any EngineSession, didUpdate state: EngineLoadState)
}

public protocol EnginePromptHandler: AnyObject {
    func engineSession(_ session: any EngineSession,
                       handle prompt: EnginePrompt) async -> EnginePromptResponse
}

public struct EnginePrompt: Sendable {
    public let message: String
    public let defaultValue: String?

    public init(message: String, defaultValue: String? = nil) {
        self.message = message
        self.defaultValue = defaultValue
    }
}

public struct EnginePromptResponse: Sendable {
    public let accepted: Bool
    public let value: String?

    public init(accepted: Bool, value: String? = nil) {
        self.accepted = accepted
        self.value = value
    }
}
