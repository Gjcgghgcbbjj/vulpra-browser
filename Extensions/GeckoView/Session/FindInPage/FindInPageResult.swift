import Foundation

public struct FindInPageResult: Equatable, Sendable {
    public let found: Bool
    public let wrapped: Bool
    public let current: Int
    public let total: Int
    public let searchString: String
    public let linkURL: String?

    public init(payload: [String: Any?]) throws {
        guard let found = Self.bool(payload["found"] ?? nil) else {
            throw FindInPageResultError.missingFoundState
        }
        guard let searchString = payload["searchString"] as? String else {
            throw FindInPageResultError.missingSearchString
        }

        self.found = found
        wrapped = Self.bool(payload["wrapped"] ?? nil) ?? false
        current = Self.int(payload["current"] ?? nil) ?? 0
        total = Self.int(payload["total"] ?? nil) ?? -1
        self.searchString = searchString
        linkURL = payload["linkURL"] as? String
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let value = value as? Bool {
            return value
        }
        return (value as? NSNumber)?.boolValue
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        return (value as? NSNumber)?.intValue
    }
}

public enum FindInPageResultError: Error, Equatable, Sendable {
    case missingFoundState
    case missingSearchString
}
