import Foundation

struct OmniboxResolution {
    let url: URL
    let httpFallbackURL: URL?
}

enum OmniboxResolver {
    static func resolve(_ input: String, settings: BrowserSettings) -> OmniboxResolution? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let explicitScheme = URLComponents(string: value)?.scheme?.lowercased()
        if let url = URL(string: value), explicitScheme == "http" || explicitScheme == "https" {
            return resolution(for: url, upgradeHTTP: settings.httpsOnly)
        }

        if looksLikeHost(value) {
            let components = URLComponents(string: "//\(value)")
            let local = isLocalHost(components?.host, hasPort: components?.port != nil)
            if let url = URL(string: "\(local ? "http" : "https")://\(value)") {
                return resolution(for: url, upgradeHTTP: false, offerHTTP: !local)
            }
        }
        return OmniboxResolution(url: settings.searchEngine.url(for: value), httpFallbackURL: nil)
    }

    private static func looksLikeHost(_ value: String) -> Bool {
        guard !value.contains(where: \.isWhitespace), !value.hasPrefix("."), !value.hasSuffix("."),
              let components = URLComponents(string: "//\(value)"), let host = components.host else { return false }
        return host.contains(".") || components.port != nil || isLocalHost(host, hasPort: false)
    }

    private static func isLocalHost(_ host: String?, hasPort: Bool) -> Bool {
        guard let host = host?.lowercased() else { return false }
        if host == "localhost" || host.hasSuffix(".local") || host.hasSuffix(".lan") ||
            host.hasSuffix(".internal") || host.contains(":") || hasPort && !host.contains(".") { return true }
        let octets = host.split(separator: ".")
        return octets.count == 4 && octets.allSatisfy { Int($0).map { (0...255).contains($0) } == true }
    }

    private static func resolution(for url: URL, upgradeHTTP: Bool, offerHTTP: Bool = false) -> OmniboxResolution {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return OmniboxResolution(url: url, httpFallbackURL: nil)
        }
        let local = isLocalHost(parts.host, hasPort: parts.port != nil)
        if upgradeHTTP, parts.scheme?.lowercased() == "http", !local {
            let fallback = url
            parts.scheme = "https"
            return OmniboxResolution(url: parts.url ?? url, httpFallbackURL: fallback)
        }
        if offerHTTP, parts.scheme?.lowercased() == "https" {
            var fallback = parts
            fallback.scheme = "http"
            return OmniboxResolution(url: url, httpFallbackURL: fallback.url)
        }
        return OmniboxResolution(url: url, httpFallbackURL: nil)
    }
}
