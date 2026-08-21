import Foundation
import GeckoView
import UIKit

enum SearchEngine: String, Codable, CaseIterable {
    case duckDuckGo, google, brave, bing

    var title: String {
        switch self {
        case .duckDuckGo: return "DuckDuckGo"
        case .google: return "Google"
        case .brave: return "Brave Search"
        case .bing: return "Bing"
        }
    }

    func url(for query: String) -> URL {
        let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let template: String
        switch self {
        case .duckDuckGo: template = "https://duckduckgo.com/?q="
        case .google: template = "https://www.google.com/search?q="
        case .brave: template = "https://search.brave.com/search?q="
        case .bing: template = "https://www.bing.com/search?q="
        }
        return URL(string: template + escaped) ?? URL(string: "about:blank")!
    }
}

enum TrackingProtectionLevel: String, Codable, CaseIterable {
    case standard, strict, custom
}

struct BrowserSettings: Codable, Equatable {
    var searchEngine: SearchEngine = .duckDuckGo
    var remoteSuggestions = false
    var darkAppearance = false
    var defaultDesktopMode = false
    var pageZoom = 100
    var trackingProtection: TrackingProtectionLevel = .standard
    var httpsOnly = true
    var historyRetentionDays = 30
    var showFavorites = true
    var showRecentVisits = true
    var showRecentlyClosed = true

    /// Google refuses sign-in from unknown browser identities ("browser may
    /// not be secure"). Claiming iOS Safari did not clear Google's interstitial
    /// — its anti-abuse cross-checks the claimed identity against deeper
    /// fingerprints (TLS stack, header order), and a Gecko engine claiming
    /// WebKit reads as inconsistent. Claiming stock Android Fenix instead:
    /// this engine IS Firefox 152 (same NSS TLS stack, same header order as
    /// real Fenix), so every checkable layer agrees, and Google never blocks
    /// genuine-looking Firefox. Mobile token keeps responsive layouts.
    static let spoofedUserAgent = "Mozilla/5.0 (Android 15; Mobile; rv:152.0) Gecko/152.0 Firefox/152.0"

    /// Kept for the Settings diagnostics comparison view.
    static let safariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1"

    /// Desktop-mode twin: same Firefox 152 identity, desktop platform token.
    static let spoofedDesktopUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:152.0) Gecko/20100101 Firefox/152.0"

    var geckoSettings: GeckoSessionSettings {
        GeckoSessionSettings(
            websiteMode: WebsiteModeSetting(
                userAgentOverride: defaultDesktopMode
                    ? BrowserSettings.spoofedDesktopUserAgent
                    : BrowserSettings.spoofedUserAgent,
                userAgentMode: 0,
                viewportMode: defaultDesktopMode ? 1 : 0
            ),
            pageZoom: PageZoomSetting(level: min(200, max(50, pageZoom))),
            language: LanguageSetting(codes: Locale.preferredLanguages),
            trackingProtection: trackingProtection != .standard
        )
    }
}

final class BrowserSettingsStore {
    static let shared = BrowserSettingsStore()
    private let store = AtomicJSONStore<BrowserSettings>(filename: "settings.json")
    private(set) var value: BrowserSettings

    private init() { value = store.load(default: BrowserSettings()) }

    func update(_ change: (inout BrowserSettings) -> Void) {
        change(&value)
        store.save(value)
        NotificationCenter.default.post(name: .browserSettingsDidChange, object: self)
    }

    /// #1: Update value in memory without posting the change notification or
    /// writing to disk. Callers (e.g. zoom slider) batch their own persist.
    func updateSilently(_ change: (inout BrowserSettings) -> Void) {
        change(&value)
    }

    /// #1: Explicitly persist the current value without notifying observers.
    func persist() {
        store.save(value)
    }
}

extension Notification.Name {
    static let browserSettingsDidChange = Notification.Name("VulpraBrowserSettingsDidChange")
}
