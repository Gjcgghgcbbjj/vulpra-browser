import Foundation

public enum FindInPageDirection: Equatable, Sendable {
    case forward
    case backward
}

public struct FindInPageDisplayOptions: OptionSet, Sendable {
    public let rawValue: Int

    public static let highlightAll = FindInPageDisplayOptions(rawValue: 1 << 0)
    public static let dimPage = FindInPageDisplayOptions(rawValue: 1 << 1)
    public static let drawLinkOutline = FindInPageDisplayOptions(rawValue: 1 << 2)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public final class SessionFinder {
    private let dispatcher: GeckoEventDispatcherWrapper

    init(dispatcher: GeckoEventDispatcherWrapper) {
        self.dispatcher = dispatcher
    }

    public func find(
        _ searchString: String?,
        direction: FindInPageDirection = .forward
    ) async throws -> FindInPageResult {
        var message: [String: Any?] = ["searchString": searchString]
        if direction == .backward {
            message["backwards"] = true
        }

        let response = try await dispatcher.query(
            type: "GeckoView:FindInPage",
            message: message
        )
        guard let values = response as? [AnyHashable: Any] else {
            throw SessionFinderError.invalidResponse
        }

        var payload: [String: Any?] = [:]
        for (key, value) in values {
            guard let key = key as? String else {
                continue
            }
            payload[key] = value
        }
        return try FindInPageResult(payload: payload)
    }

    public func setDisplayOptions(_ options: FindInPageDisplayOptions) {
        dispatcher.dispatch(
            type: "GeckoView:DisplayMatches",
            message: [
                "highlightAll": options.contains(.highlightAll),
                "dimPage": options.contains(.dimPage),
                "drawOutline": options.contains(.drawLinkOutline),
            ]
        )
    }

    public func clear() {
        dispatcher.dispatch(type: "GeckoView:ClearMatches")
    }
}

public enum SessionFinderError: Error, Equatable, Sendable {
    case invalidResponse
}
