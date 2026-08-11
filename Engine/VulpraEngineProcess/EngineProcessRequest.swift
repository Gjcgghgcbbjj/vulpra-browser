import CoreFoundation
import Foundation

enum EngineProcessRequestError: Error, LocalizedError, Equatable {
    case missing(String)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case let .missing(field):
            return "Missing engine process request field: \(field)"
        case let .invalid(field):
            return "Invalid engine process request field: \(field)"
        }
    }
}

struct EngineProcessRequest {
    static let protocolVersion = 2
    static let maximumProcessTypeLength = 64

    let endpoint: NSXPCListenerEndpoint
    let launchID: UInt64
    let childID: Int32
    let processType: String

    init(userInfo: [AnyHashable: Any]?) throws {
        guard let userInfo else {
            throw EngineProcessRequestError.missing("userInfo")
        }

        let version = try Self.integer(
            userInfo["VulpraEngineProcessProtocolVersion"],
            field: "VulpraEngineProcessProtocolVersion"
        )
        guard version == UInt64(Self.protocolVersion) else {
            throw EngineProcessRequestError.invalid("VulpraEngineProcessProtocolVersion")
        }
        guard let endpoint = userInfo["VulpraXPCListenerEndpoint"] as? NSXPCListenerEndpoint else {
            throw EngineProcessRequestError.missing("VulpraXPCListenerEndpoint")
        }

        let launchID = try Self.integer(
            userInfo["VulpraChildLaunchID"], field: "VulpraChildLaunchID"
        )
        guard launchID > 0 else {
            throw EngineProcessRequestError.invalid("VulpraChildLaunchID")
        }

        let childIDValue = try Self.integer(
            userInfo["VulpraGeckoChildID"], field: "VulpraGeckoChildID"
        )
        guard childIDValue > 0, childIDValue <= UInt64(Int32.max) else {
            throw EngineProcessRequestError.invalid("VulpraGeckoChildID")
        }

        guard let processType = userInfo["VulpraGeckoProcessType"] as? String else {
            throw EngineProcessRequestError.missing("VulpraGeckoProcessType")
        }
        guard !processType.isEmpty,
              processType.count <= Self.maximumProcessTypeLength,
              processType.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw EngineProcessRequestError.invalid("VulpraGeckoProcessType")
        }

        self.endpoint = endpoint
        self.launchID = launchID
        childID = Int32(childIDValue)
        self.processType = processType
    }

    private static func integer(_ value: Any?, field: String) throws -> UInt64 {
        guard let number = value as? NSNumber else {
            throw EngineProcessRequestError.missing(field)
        }
        guard CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite,
              number.doubleValue >= 0,
              number.doubleValue.rounded(.towardZero) == number.doubleValue,
              number.decimalValue <= NSNumber(value: UInt64.max).decimalValue else {
            throw EngineProcessRequestError.invalid(field)
        }
        return number.uint64Value
    }
}
