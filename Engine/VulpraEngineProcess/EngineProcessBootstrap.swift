import Foundation

public enum EngineProcessRole: String, Codable, Sendable {
    case content
    case graphics
    case network
    case utility
}

public enum EngineProcessBootstrapError: Error, Equatable, Sendable {
    case missing(String)
    case duplicate(String)
    case invalid(String)
    case unknown(String)
}

public struct EngineProcessBootstrap: Equatable, Sendable {
    public let role: EngineProcessRole
    public let endpointToken: String
    public let parentProcessIdentifier: Int32

    public init(arguments: [String]) throws {
        let rolePrefix = "--vulpra-process-role="
        let endpointPrefix = "--vulpra-endpoint-token="
        let parentPrefix = "--vulpra-parent-pid="
        var roleValue: String?
        var endpointValue: String?
        var parentValue: String?

        for argument in arguments {
            if argument.hasPrefix(rolePrefix) {
                try Self.assign(
                    String(argument.dropFirst(rolePrefix.count)),
                    to: &roleValue,
                    field: "role"
                )
            } else if argument.hasPrefix(endpointPrefix) {
                try Self.assign(
                    String(argument.dropFirst(endpointPrefix.count)),
                    to: &endpointValue,
                    field: "endpoint-token"
                )
            } else if argument.hasPrefix(parentPrefix) {
                try Self.assign(
                    String(argument.dropFirst(parentPrefix.count)),
                    to: &parentValue,
                    field: "parent-pid"
                )
            } else if argument.hasPrefix("--vulpra-") {
                throw EngineProcessBootstrapError.unknown(argument)
            }
        }

        guard let roleValue else {
            throw EngineProcessBootstrapError.missing("role")
        }
        guard let role = EngineProcessRole(rawValue: roleValue) else {
            throw EngineProcessBootstrapError.invalid("role")
        }
        guard let endpointValue else {
            throw EngineProcessBootstrapError.missing("endpoint-token")
        }
        let allowedTokenCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard !endpointValue.isEmpty,
              endpointValue.unicodeScalars.allSatisfy(allowedTokenCharacters.contains) else {
            throw EngineProcessBootstrapError.invalid("endpoint-token")
        }
        guard let parentValue else {
            throw EngineProcessBootstrapError.missing("parent-pid")
        }
        guard let parentIdentifier = Int32(parentValue), parentIdentifier > 0 else {
            throw EngineProcessBootstrapError.invalid("parent-pid")
        }

        self.role = role
        endpointToken = endpointValue
        parentProcessIdentifier = parentIdentifier
    }

    private static func assign(
        _ value: String,
        to destination: inout String?,
        field: String
    ) throws {
        guard destination == nil else {
            throw EngineProcessBootstrapError.duplicate(field)
        }
        destination = value
    }
}
