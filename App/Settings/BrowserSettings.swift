import Foundation
import UIKit
import VulpraEngineKit

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
        var components: URLComponents
        switch self {
        case .duckDuckGo: components = URLComponents(string: "https://duckduckgo.com/")!
        case .google: components = URLComponents(string: "https://www.google.com/search")!
        case .brave: components = URLComponents(string: "https://search.brave.com/search")!
        case .bing: components = URLComponents(string: "https://www.bing.com/search")!
        }
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url ?? URL(string: "about:blank")!
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

    func engineConfiguration(isPrivate: Bool) -> EngineSessionConfiguration {
        EngineSessionConfiguration(
            isPrivate: isPrivate,
            userAgentMode: defaultDesktopMode ? .desktop : .mobile,
            pageZoom: Double(min(200, max(50, pageZoom))) / 100,
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
