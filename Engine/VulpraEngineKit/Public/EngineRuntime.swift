import Foundation

public protocol EngineRuntime: AnyObject {
    var state: EngineRuntimeState { get }
    var capabilities: EngineCapabilities { get }
    func start() async throws
    func makeSession(privateMode: Bool) async throws -> any EngineSession
    func shutdown() async
}
