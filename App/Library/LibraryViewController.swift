import UIKit

enum LibrarySection { case bookmarks, history }

final class LibraryViewController: UITableViewController, UISearchResultsUpdating {
    private let section: LibrarySection
    private var query = ""
    private lazy var emptyState = VulpraEmptyStateView(
        symbol: section == .bookmarks ? "star" : "clock",
        title: VulpraL10n.text(section == .bookmarks ? "empty.bookmarks" : "empty.history")
    )
    var onOpenURL: ((URL) -> Void)?

    init(section: LibrarySection) {
        self.section = section
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = VulpraL10n.text(section == .bookmarks ? "library.bookmarks" : "library.history")
        navigationItem.rightBarButtonItem = section == .history
            ? UIBarButtonItem(title: VulpraL10n.text("common.clear"), style: .plain,
                              target: self, action: #selector(clearHistory)) : nil
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = search
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LibraryCell")
        refresh()
    }

    private var bookmarks: [Bookmark] { BookmarkStore.shared.search(query).filter { !$0.isFolder } }
    private var history: [HistoryVisit] { HistoryStore.shared.search(query) }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.section == .bookmarks ? bookmarks.count : history.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LibraryCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        if section == .bookmarks {
            let item = bookmarks[indexPath.row]
            content.text = item.title
            content.secondaryText = item.url
            content.image = UIImage(systemName: "star")
        } else {
            let item = history[indexPath.row]
            content.text = item.title
            content.secondaryText = item.url
            content.image = UIImage(systemName: "clock")
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let value = section == .bookmarks ? bookmarks[indexPath.row].url : history[indexPath.row].url
        guard let value, let url = URL(string: value) else { return }
        onOpenURL?(url)
        dismiss(animated: true)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        if section == .bookmarks { BookmarkStore.shared.remove(bookmarks[indexPath.row]) }
        else { HistoryStore.shared.remove(history[indexPath.row]) }
        refresh()
    }

    func updateSearchResults(for searchController: UISearchController) {
        query = searchController.searchBar.text ?? ""
        refresh()
    }

    @objc private func clearHistory() {
        let alert = UIAlertController(
            title: VulpraL10n.text("library.clear_history.title"),
            message: VulpraL10n.text("library.clear_history.message"),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: VulpraL10n.text("library.clear_history"), style: .destructive) { _ in
            HistoryStore.shared.clear(); self.refresh()
        })
        alert.addAction(UIAlertAction(title: VulpraL10n.text("common.cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func refresh() {
        tableView.reloadData()
        let isEmpty = section == .bookmarks ? bookmarks.isEmpty : history.isEmpty
        tableView.backgroundView = isEmpty ? emptyState : nil
    }
}
