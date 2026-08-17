import Foundation

public enum EngineExecutionMode: String, Codable, Sendable {
    case interpreter
    case accelerated
    case unavailable
}

public struct EngineCapabilities: Codable, Equatable, Sendable {
    public let executionMode: EngineExecutionMode
    public let supportsPrivateBrowsing: Bool
    public let supportsDownloads: Bool
    public let supportsExtensions: Bool

    public init(executionMode: EngineExecutionMode = .interpreter,
                supportsPrivateBrowsing: Bool = true,
                supportsDownloads: Bool = true,
                supportsExtensions: Bool = false) {
        self.executionMode = executionMode
        self.supportsPrivateBrowsing = supportsPrivateBrowsing
        self.supportsDownloads = supportsDownloads
        self.supportsExtensions = supportsExtensions
    }
}

public enum EngineRuntimeState: String, Sendable {
    case stopped
    case starting
    case ready
    case failed
}
