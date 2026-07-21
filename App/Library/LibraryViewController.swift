import UIKit

enum LibrarySection { case bookmarks, history }

final class LibraryViewController: UITableViewController, UISearchResultsUpdating {
    private let section: LibrarySection
    private var query = ""
    var onOpenURL: ((URL) -> Void)?

    init(section: LibrarySection) {
        self.section = section
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = section == .bookmarks ? "Bookmarks" : "History"
        navigationItem.rightBarButtonItem = section == .history
            ? UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearHistory)) : nil
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = search
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LibraryCell")
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
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    func updateSearchResults(for searchController: UISearchController) {
        query = searchController.searchBar.text ?? ""
        tableView.reloadData()
    }

    @objc private func clearHistory() {
        let alert = UIAlertController(title: "Clear History?", message: "Bookmarks and downloads are not removed.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Clear History", style: .destructive) { _ in
            HistoryStore.shared.clear(); self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
