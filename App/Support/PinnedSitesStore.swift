import Foundation

/// A site pinned to the start page. Distinct from bookmarks: pinning is a
/// one-tap "keep this handy" action managed from the page menu, with the
/// start-page grid and its context menus as the only surface.
struct PinnedSite: Codable, Equatable {
    let title: String
    let url: String
    let addedAt: Date
}

final class PinnedSitesStore {
    static let shared = PinnedSitesStore()

    private let store = AtomicJSONStore<[PinnedSite]>(filename: "pinned-sites.json")
    private(set) var sites: [PinnedSite] = []

    private init() {
        sites = store.load(default: [])
    }

    func contains(url: URL) -> Bool {
        let key = url.absoluteString
        return sites.contains { $0.url == key }
    }

    func pin(title: String, url: URL) {
        let key = url.absoluteString
        guard !sites.contains(where: { $0.url == key }) else { return }
        sites.append(PinnedSite(title: title, url: key, addedAt: Date()))
        persist()
    }

    func unpin(url: URL) {
        let key = url.absoluteString
        guard sites.contains(where: { $0.url == key }) else { return }
        sites.removeAll { $0.url == key }
        persist()
    }

    private func persist() {
        store.save(sites)
        NotificationCenter.default.post(name: .pinnedSitesDidChange, object: nil)
    }
}

extension Notification.Name {
    static let pinnedSitesDidChange = Notification.Name("pinnedSitesDidChange")
}
