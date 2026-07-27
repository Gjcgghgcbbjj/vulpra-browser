import UIKit
import VulpraEngineKit

final class PrivacyDataViewController: UITableViewController {
    private let runtime: any EngineRuntime
    private let rows: [(String, String, EngineStorageClearOptions)] = [
        (VulpraL10n.text("privacy.clear_cookies"), "doc.text", .cookies),
        (VulpraL10n.text("privacy.clear_web_storage"), "externaldrive", .webStorage),
        (VulpraL10n.text("privacy.clear_caches"), "archivebox", .cache),
        (VulpraL10n.text("privacy.clear_authentication"), "key", .authentication),
        (VulpraL10n.text("privacy.clear_all"), "trash", .all),
    ]

    init(runtime: any EngineRuntime) {
        self.runtime = runtime
        super.init(style: .insetGrouped)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad(); title = VulpraL10n.text("privacy.clear_data")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DataCell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count + 1 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DataCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        if indexPath.row == rows.count {
            content.text = VulpraL10n.text("privacy.clear_history")
            content.image = UIImage(systemName: "clock.arrow.circlepath")
        } else {
            content.text = rows[indexPath.row].0
            content.image = UIImage(systemName: rows[indexPath.row].1)
        }
        content.textProperties.color = .systemRed
        content.imageProperties.tintColor = .systemRed
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == rows.count { HistoryStore.shared.clear() }
        else { runtime.clearData(rows[indexPath.row].2) }
        let alert = UIAlertController(title: VulpraL10n.text("privacy.cleared"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: VulpraL10n.text("common.ok"), style: .default)); present(alert, animated: true)
    }
}
