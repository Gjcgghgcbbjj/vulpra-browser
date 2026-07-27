import Foundation

public struct EngineRuntimeConfiguration: Equatable, Sendable {
    public let localeIdentifier: String

    public init(localeIdentifier: String) {
        self.localeIdentifier = localeIdentifier
    }
}

public enum EngineRuntimeState: Equatable, Sendable {
    case stopped
    case starting
    case ready(EngineCapabilities)
    case failed(EngineFailure)
}

@MainActor
public protocol EngineRuntime: AnyObject, Sendable {
    var state: EngineRuntimeState { get }

    func start(configuration: EngineRuntimeConfiguration) async throws -> EngineCapabilities
    func makeSession(configuration: EngineSessionConfiguration) -> any EngineSession
    func clearData(_ options: EngineStorageClearOptions)
}
