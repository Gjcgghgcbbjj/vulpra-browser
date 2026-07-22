import Foundation

struct Bookmark: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var url: String?
    var parentID: UUID?
    var createdAt: Date
    var isFolder: Bool
}

struct HistoryVisit: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var url: String
    var visitedAt: Date
}

final class BookmarkStore {
    static let shared = BookmarkStore()
    private let store = AtomicJSONStore<[Bookmark]>(filename: "bookmarks.json")
    private(set) var items: [Bookmark]
    private init() { items = store.load(default: []) }

    func add(title: String, url: URL) {
        guard !items.contains(where: { $0.url == url.absoluteString && !$0.isFolder }) else { return }
        items.insert(Bookmark(id: UUID(), title: title, url: url.absoluteString,
                              parentID: nil, createdAt: Date(), isFolder: false), at: 0)
        persist()
    }

    func addFolder(title: String, parentID: UUID? = nil) {
        items.insert(Bookmark(id: UUID(), title: title, url: nil,
                              parentID: parentID, createdAt: Date(), isFolder: true), at: 0)
        persist()
    }

    func remove(_ item: Bookmark) { items.removeAll { $0.id == item.id }; persist() }

    func search(_ query: String) -> [Bookmark] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(query) || ($0.url?.localizedCaseInsensitiveContains(query) ?? false) }
    }

    private func persist() { items = Array(items.prefix(5_000)); store.save(items) }
}

final class HistoryStore {
    static let shared = HistoryStore()
    private let store = AtomicJSONStore<[HistoryVisit]>(filename: "history.json")
    private(set) var visits: [HistoryVisit]
    private init() { visits = store.load(default: []) }

    func record(title: String, url: URL, privateMode: Bool) {
        guard !privateMode, let scheme = url.scheme, scheme == "http" || scheme == "https" else { return }
        visits.insert(HistoryVisit(id: UUID(), title: title, url: url.absoluteString, visitedAt: Date()), at: 0)
        trim(retentionDays: BrowserSettingsStore.shared.value.historyRetentionDays)
    }

    func trim(retentionDays: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -max(1, retentionDays), to: Date()) ?? .distantPast
        visits = Array(visits.filter { $0.visitedAt >= cutoff }.prefix(5_000))
        store.save(visits)
    }

    func remove(_ visit: HistoryVisit) { visits.removeAll { $0.id == visit.id }; store.save(visits) }
    func clear() { visits.removeAll(); store.save(visits) }

    func search(_ query: String) -> [HistoryVisit] {
        guard !query.isEmpty else { return visits }
        return visits.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.url.localizedCaseInsensitiveContains(query) }
    }
}
