import GeckoView
import UIKit

final class PrivacyDataViewController: UITableViewController {
    private let rows: [(String, Int64)] = [
        ("Clear Cookies", GeckoStorageClearFlags.cookies),
        ("Clear Web Storage", GeckoStorageClearFlags.domStorages),
        ("Clear Caches", GeckoStorageClearFlags.allCaches),
        ("Clear Authentication Sessions", GeckoStorageClearFlags.authSessions),
        ("Clear All Website Data", GeckoStorageClearFlags.cookies | GeckoStorageClearFlags.domStorages |
            GeckoStorageClearFlags.allCaches | GeckoStorageClearFlags.authSessions),
    ]

    init() { super.init(style: .insetGrouped) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Clear Browsing Data"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DataCell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count + 1 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DataCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = indexPath.row == rows.count ? "Clear History" : rows[indexPath.row].0
        content.textProperties.color = .systemRed
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        Task {
            if indexPath.row == rows.count {
                try? await GeckoStorageController.clearHistory(since: nil)
                HistoryStore.shared.clear()
            } else {
                try? await GeckoStorageController.clearData(flags: rows[indexPath.row].1)
            }
            let alert = UIAlertController(title: "Cleared", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
