import Foundation

public enum EngineSessionError: Error, Sendable {
    case closed
    case runtimeUnavailable
    case invalidURL
}

public protocol EngineRequestCancellation: AnyObject {
    var isCancelled: Bool { get }
    func cancel()
}

public protocol EngineSession: AnyObject {
    var id: EngineSessionID { get }
    var isPrivate: Bool { get }
    var navigationObserver: (any EngineNavigationObserver)? { get set }
    var progressObserver: (any EngineProgressObserver)? { get set }
    var promptHandler: (any EnginePromptHandler)? { get set }
    @MainActor var engineView: (any EngineView)? { get }

    func open() async throws
    func close() async
    func navigate(to url: URL) async throws
    func goBack() async
    func goForward() async
    func reload() async
    func cancelPendingRequests()
}
