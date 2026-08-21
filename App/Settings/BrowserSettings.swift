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
    /// not be secure"). Claiming the iOS Safari identity per session gives
    /// maximum page compatibility — applied at the session-settings layer so
    /// every tab presents it regardless of desktop-mode toggles.
    static let safariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1"

    var geckoSettings: GeckoSessionSettings {
        GeckoSessionSettings(
            websiteMode: WebsiteModeSetting(
                userAgentOverride: BrowserSettings.safariUserAgent,
                userAgentMode: defaultDesktopMode ? 1 : 0,
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
