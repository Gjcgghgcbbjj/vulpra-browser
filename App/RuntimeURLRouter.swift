import Foundation

/// Everything the `vulpra://` scheme (and plain web URLs) can ask the app to do.
/// Deep links double as the automation surface: CI navigates screens through
/// them instead of fragile coordinate taps.
enum InternalRoute: Equatable {
    case web(URL)
    case settings
    case bookmarks
    case history
    case downloads
    case tabs
    case extensions
    case sitePermissions
    case privacyData
    case newTab(isPrivate: Bool)
}

enum RuntimeURLRouter {
    /// Maps an incoming URL to a route. Web URLs pass through; `vulpra://`
    /// hosts map to in-app screens. Unknown hosts resolve to nil (ignored).
    static func resolve(_ input: URL?) -> InternalRoute? {
        guard let input else {
            return nil
        }

        if isWebURL(input) {
            return .web(input)
        }

        guard input.scheme?.lowercased() == "vulpra" else {
            return nil
        }

        let components = URLComponents(url: input, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let host = input.host?.lowercased() ?? ""

        switch host {
        case "open":
            let urlItems = queryItems.filter { $0.name == "url" }
            guard
                urlItems.count == 1,
                let value = urlItems[0].value,
                let nestedURL = URL(string: value),
                isWebURL(nestedURL)
            else {
                return nil
            }
            return .web(nestedURL)

        case "settings":
            return .settings
        case "bookmarks":
            return .bookmarks
        case "history":
            return .history
        case "downloads":
            return .downloads
        case "tabs":
            return .tabs
        case "extensions":
            return .extensions
        case "permissions", "site-permissions":
            return .sitePermissions
        case "privacy", "clear-data":
            return .privacyData
        case "new-tab", "newtab":
            let isPrivate = queryItems.first(where: { $0.name == "private" })?.value == "1"
            return .newTab(isPrivate: isPrivate)
        default:
            return nil
        }
    }

    private static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }
}
