import Foundation

public enum GeckoFeatureCapability: String, CaseIterable, Codable, Hashable, Sendable {
    case nightMode
    case contentBlocking
    case userScripts
    case privacy
}

public struct GeckoFeatureCapabilities: Equatable, Sendable {
    public let supported: Set<GeckoFeatureCapability>

    public init(payload: [String: Any?]) {
        supported = Set(GeckoFeatureCapability.allCases.filter { capability in
            (payload[capability.rawValue] as? Bool) == true ||
            (payload[capability.rawValue] as? NSNumber)?.boolValue == true
        })
    }
}

public final class SessionFeatureBridge {
    private let dispatcher: GeckoEventDispatcherWrapper

    init(dispatcher: GeckoEventDispatcherWrapper) {
        self.dispatcher = dispatcher
    }

    public func capabilities() async -> GeckoFeatureCapabilities {
        let response = try? await dispatcher.query(type: "Vulpra:Features:GetCapabilities")
        return GeckoFeatureCapabilities(payload: response as? [String: Any?] ?? [:])
    }

    public func applyNightMode(enabled: Bool, host: String?) {
        dispatcher.dispatch(type: "Vulpra:Features:NightMode", message: ["enabled": enabled, "host": host as Any])
    }

    public func applyContentBlocking(mode: String, disabledHosts: [String], subscriptions: [[String: Any]], customRules: [String]) {
        dispatcher.dispatch(type: "Vulpra:Features:ContentBlocking", message: [
            "mode": mode,
            "disabledHosts": disabledHosts,
            "subscriptions": subscriptions,
            "customRules": customRules,
            "updateRetryLimit": 3,
        ])
    }

    public func applyUserScripts(_ scripts: [[String: Any]], privateMode: Bool) {
        dispatcher.dispatch(type: "Vulpra:Features:UserScripts", message: ["scripts": scripts, "privateMode": privateMode])
    }

    public func applyPrivacy(cookiePolicy: String, trackingProtection: Bool, clearSiteDataOnExit: Bool) {
        dispatcher.dispatch(type: "Vulpra:Features:Privacy", message: [
            "thirdPartyCookies": cookiePolicy,
            "trackingProtection": trackingProtection,
            "clearSiteDataOnExit": clearSiteDataOnExit,
        ])
    }
}
