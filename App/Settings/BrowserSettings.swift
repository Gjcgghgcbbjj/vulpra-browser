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

    var geckoSettings: GeckoSessionSettings {
        GeckoSessionSettings(
            websiteMode: defaultDesktopMode
                ? WebsiteModeSetting(userAgentOverride: nil, userAgentMode: 1, viewportMode: 1)
                : .mobile,
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
}

extension Notification.Name {
    static let browserSettingsDidChange = Notification.Name("VulpraBrowserSettingsDidChange")
}
