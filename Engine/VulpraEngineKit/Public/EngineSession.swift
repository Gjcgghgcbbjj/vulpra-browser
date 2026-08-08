import Foundation

public enum EngineUserAgentMode: String, Codable, Sendable {
    case mobile
    case desktop
}

public enum EngineTrackingProtectionLevel: String, Codable, Sendable {
    case off
    case standard
    case strict
}

public struct EngineSessionConfiguration: Equatable, Sendable {
    public let isPrivate: Bool
    public let userAgentMode: EngineUserAgentMode
    public let pageZoom: Double
    public let trackingProtection: EngineTrackingProtectionLevel

    public init(isPrivate: Bool, userAgentMode: EngineUserAgentMode, pageZoom: Double,
                trackingProtection: EngineTrackingProtectionLevel = .standard) {
        self.isPrivate = isPrivate
        self.userAgentMode = userAgentMode
        self.pageZoom = pageZoom
        self.trackingProtection = trackingProtection
    }
}

public struct EngineNavigationRequest: Equatable, Sendable {
    public let url: URL
    public let userInitiated: Bool

    public init(url: URL, userInitiated: Bool = true) {
        self.url = url
        self.userInitiated = userInitiated
    }
}

public enum EngineSessionState: Equatable, Sendable {
    case closed
    case opening
    case open
    case closing
    case failed(EngineFailure)
}

@MainActor
public protocol EngineSession: AnyObject, Sendable {
    var id: EngineSessionID { get }
    var state: EngineSessionState { get }
    var configuration: EngineSessionConfiguration { get }
    var navigationObserver: (any EngineNavigationObserver)? { get set }
    var progressObserver: (any EngineProgressObserver)? { get set }
    var contentObserver: (any EngineContentObserver)? { get set }
    var promptHandler: (any EnginePromptHandler)? { get set }
    var permissionHandler: (any EnginePermissionHandler)? { get set }
    var downloadHandler: (any EngineDownloadHandler)? { get set }

    @MainActor
    func makeView() -> any EngineView

    func open(windowID: String?)
    func close()
    func load(_ request: EngineNavigationRequest)
    func goBack()
    func goForward()
    func reload()
    func stop()
    func setActive(_ active: Bool)
    func setFocused(_ focused: Bool)
    func update(configuration: EngineSessionConfiguration)
}
