import Foundation

enum OmniboxResolver {
    static func resolve(_ input: String, settings: BrowserSettings) -> URL? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let url = URL(string: value), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return enforceHTTPS(url, enabled: settings.httpsOnly)
        }

        if looksLikeHost(value), let url = URL(string: "https://\(value)") {
            return url
        }
        return settings.searchEngine.url(for: value)
    }

    private static func looksLikeHost(_ value: String) -> Bool {
        !value.contains(" ") && value.contains(".") && !value.hasPrefix(".") && !value.hasSuffix(".")
    }

    private static func enforceHTTPS(_ url: URL, enabled: Bool) -> URL {
        guard enabled, url.scheme?.lowercased() == "http", var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        parts.scheme = "https"
        return parts.url ?? url
    }
}
