import UIKit

enum LibrarySection { case bookmarks, history }

final class LibraryViewController: UITableViewController, UISearchResultsUpdating {
    private let section: LibrarySection
    private var query = ""
    private let emptyTitle = UILabel()
    private let emptyHint = UILabel()
    private let emptyIcon = UIImageView()
    var onOpenURL: ((URL) -> Void)?

    init(section: LibrarySection) {
        self.section = section
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = section == .bookmarks ? L10n.tr("Bookmarks", "书签") : L10n.tr("History", "历史记录")
        navigationItem.rightBarButtonItem = section == .history
            ? UIBarButtonItem(title: L10n.tr("Clear", "清除"), style: .plain,
                              target: self, action: #selector(clearHistory)) : nil
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = L10n.tr("Search", "搜索")
        navigationItem.searchController = search
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LibraryCell")
        configureEmptyState()
    }

    private var bookmarks: [Bookmark] { BookmarkStore.shared.search(query).filter { !$0.isFolder } }
    private var history: [HistoryVisit] { HistoryStore.shared.search(query) }

    private func configureEmptyState() {
        emptyIcon.image = UIImage(systemName: section == .bookmarks ? "star" : "clock.arrow.circlepath")
        emptyIcon.tintColor = .tertiaryLabel
        emptyIcon.contentMode = .center
        emptyIcon.translatesAutoresizingMaskIntoConstraints = false
        emptyTitle.text = section == .bookmarks
            ? L10n.tr("No bookmarks yet", "还没有书签")
            : L10n.tr("No history yet", "还没有历史记录")
        emptyTitle.font = .preferredFont(forTextStyle: .title3)
        emptyTitle.textColor = .secondaryLabel
        emptyTitle.textAlignment = .center
        emptyHint.text = section == .bookmarks
            ? L10n.tr("Tap ⋯ → Add Bookmark on any page.", "在任意页面点 ⋯ → 添加书签。")
            : L10n.tr("Pages you visit will appear here.", "访问过的网页会出现在这里。")
        emptyHint.font = .preferredFont(forTextStyle: .footnote)
        emptyHint.textColor = .tertiaryLabel
        emptyHint.textAlignment = .center
        [emptyIcon, emptyTitle, emptyHint].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isHidden = true
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            emptyIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyIcon.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -44),
            emptyIcon.heightAnchor.constraint(equalToConstant: 44),
            emptyTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyTitle.topAnchor.constraint(equalTo: emptyIcon.bottomAnchor, constant: 14),
            emptyTitle.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            emptyHint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyHint.topAnchor.constraint(equalTo: emptyTitle.bottomAnchor, constant: 6),
            emptyHint.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
        ])
    }

    private func updateEmptyState() {
        let empty = section == .bookmarks ? bookmarks.isEmpty : history.isEmpty
        emptyIcon.isHidden = !empty
        emptyTitle.isHidden = !empty
        emptyHint.isHidden = !empty
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = self.section == .bookmarks ? bookmarks.count : history.count
        updateEmptyState()
        return count
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
        let alert = UIAlertController(
            title: L10n.tr("Clear History?", "清除历史记录？"),
            message: L10n.tr("Bookmarks and downloads are not removed.", "书签和下载不会被删除。"),
            preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: L10n.tr("Clear History", "清除历史记录"), style: .destructive) { _ in
            HistoryStore.shared.clear()
            self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: L10n.tr("Cancel", "取消"), style: .cancel))
        // Required popover anchor on iPad — without it the system terminates the app.
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }
}
