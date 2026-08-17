import Foundation

public struct EngineProcessBootstrap: Sendable, Equatable {
    public let runtimeRoot: URL
    public let endpointName: String
    public let protocolVersion: Int

    public init(arguments: [String]) throws {
        var values: [String: String] = [:]
        for argument in arguments where argument.hasPrefix("--") {
            let parts = argument.dropFirst(2).split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
                throw EngineProcessBootstrapError.invalidArgument(argument)
            }
            guard values[parts[0]] == nil else {
                throw EngineProcessBootstrapError.duplicateArgument(parts[0])
            }
            values[parts[0]] = parts[1]
        }

        guard let root = values["runtime-root"], !root.hasPrefix("-") else {
            throw EngineProcessBootstrapError.missingArgument("runtime-root")
        }
        guard let endpoint = values["endpoint"], endpoint.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
            throw EngineProcessBootstrapError.invalidArgument("endpoint")
        }
        guard let versionValue = values["protocol-version"], let version = Int(versionValue), version > 0 else {
            throw EngineProcessBootstrapError.invalidArgument("protocol-version")
        }
        let url = URL(fileURLWithPath: root).standardizedFileURL
        guard !url.pathComponents.contains("..") else {
            throw EngineProcessBootstrapError.invalidArgument("runtime-root")
        }
        runtimeRoot = url
        endpointName = endpoint
        protocolVersion = version
    }
}

public enum EngineProcessBootstrapError: Error, Equatable, Sendable {
    case missingArgument(String)
    case duplicateArgument(String)
    case invalidArgument(String)
}
