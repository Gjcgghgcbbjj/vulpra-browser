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

/// Host-process memory pressure levels surfaced from the UIKit runtime so the
/// App layer can reclaim resources before UIKit's late `didReceiveMemoryWarning`
/// (which only fires close to the critical threshold).
public enum EngineRuntimeMemoryPressure: Equatable, Sendable {
    case warning
    case critical
}

@MainActor
public protocol EngineRuntime: AnyObject, Sendable {
    var state: EngineRuntimeState { get }

    /// Optional observer for host-process memory pressure. The engine host
    /// registers a `dispatch_source_memorypressure` source (warning/critical)
    /// and delivers levels on the main actor. App shells should downgrade or
    /// suspend background tabs here, ahead of the UIKit warning.
    var onMemoryPressure: ((EngineRuntimeMemoryPressure) -> Void)? { get set }

    func start(configuration: EngineRuntimeConfiguration) async throws -> EngineCapabilities
    func makeSession(configuration: EngineSessionConfiguration) -> any EngineSession
    func clearData(_ options: EngineStorageClearOptions)
}
