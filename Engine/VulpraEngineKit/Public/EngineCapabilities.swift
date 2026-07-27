import Foundation

public enum EngineExecutionMode: String, Codable, Sendable {
    case interpreter
    case accelerated
}

public enum EngineDistributionProfile: String, Codable, Sendable {
    case externalSigning = "external-signing"
    case trollStore = "trollstore"
}

public enum EngineSandboxAuthority: String, Codable, Sendable {
    case extensionKit = "extensionkit"
}

public struct EngineCapabilities: Codable, Equatable, Sendable {
    public let executionMode: EngineExecutionMode
    public let supportsPrompts: Bool
    public let supportsPermissions: Bool
    public let supportsDownloads: Bool
    public let supportsStorage: Bool
    public let supportsExtensions: Bool
    public let supportsPictureInPicture: Bool
    public let supportsBackgroundMedia: Bool
    public let distributionProfile: EngineDistributionProfile
    public let sandboxAuthority: EngineSandboxAuthority
    public let usesPrivateProcessTransport: Bool

    public init(
        executionMode: EngineExecutionMode,
        supportsPrompts: Bool,
        supportsPermissions: Bool,
        supportsDownloads: Bool,
        supportsStorage: Bool,
        supportsExtensions: Bool,
        supportsPictureInPicture: Bool,
        supportsBackgroundMedia: Bool,
        distributionProfile: EngineDistributionProfile,
        sandboxAuthority: EngineSandboxAuthority,
        usesPrivateProcessTransport: Bool
    ) {
        self.executionMode = executionMode
        self.supportsPrompts = supportsPrompts
        self.supportsPermissions = supportsPermissions
        self.supportsDownloads = supportsDownloads
        self.supportsStorage = supportsStorage
        self.supportsExtensions = supportsExtensions
        self.supportsPictureInPicture = supportsPictureInPicture
        self.supportsBackgroundMedia = supportsBackgroundMedia
        self.distributionProfile = distributionProfile
        self.sandboxAuthority = sandboxAuthority
        self.usesPrivateProcessTransport = usesPrivateProcessTransport
    }
}
