import Foundation

struct OmniboxSuggestion: Equatable {
    let title: String
    let detail: String
    let value: String
    let symbol: String
}

enum OmniboxSuggestionProvider {
    static func suggestions(for query: String, tabs: [BrowserTab], limit: Int = 12) -> [OmniboxSuggestion] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return [] }
        var results: [OmniboxSuggestion] = []
        for tab in tabs where matches(value, title: tab.title, url: tab.url?.absoluteString) {
            if let url = tab.url?.absoluteString {
                results.append(OmniboxSuggestion(title: tab.title, detail: url, value: url, symbol: "square.on.square"))
            }
        }
        for bookmark in BookmarkStore.shared.search(value).prefix(6) where !bookmark.isFolder {
            if let url = bookmark.url {
                results.append(OmniboxSuggestion(title: bookmark.title, detail: url, value: url, symbol: "star"))
            }
        }
        for visit in HistoryStore.shared.search(value).prefix(8) {
            results.append(OmniboxSuggestion(title: visit.title, detail: visit.url, value: visit.url, symbol: "clock"))
        }
        var seen = Set<String>()
        return results.filter { seen.insert($0.value).inserted }.prefix(limit).map { $0 }
    }

    private static func matches(_ query: String, title: String, url: String?) -> Bool {
        title.localizedCaseInsensitiveContains(query) || (url?.localizedCaseInsensitiveContains(query) ?? false)
    }
}
