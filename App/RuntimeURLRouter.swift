import Foundation

enum RuntimeURLRouter {
    static func resolve(_ input: URL?) -> URL? {
        guard let input else {
            return nil
        }

        if isWebURL(input) {
            return input
        }

        guard
            input.scheme?.lowercased() == "vulpra",
            input.host?.lowercased() == "open",
            let components = URLComponents(url: input, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        let urlItems = components.queryItems?.filter { item in
            item.name == "url"
        } ?? []

        guard
            urlItems.count == 1,
            let value = urlItems[0].value,
            let nestedURL = URL(string: value),
            isWebURL(nestedURL)
        else {
            return nil
        }

        return nestedURL
    }

    private static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }
}
