import UIKit
import VulpraEngineKit

final class PrivacyDataViewController: UITableViewController {
    private let runtime: any EngineRuntime
    private let rows: [(String, EngineStorageClearOptions)] = [
        (VulpraL10n.text("privacy.clear_cookies"), .cookies),
        (VulpraL10n.text("privacy.clear_web_storage"), .webStorage),
        (VulpraL10n.text("privacy.clear_caches"), .cache),
        (VulpraL10n.text("privacy.clear_authentication"), .authentication),
        (VulpraL10n.text("privacy.clear_all"), .all),
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
        content.text = indexPath.row == rows.count ? VulpraL10n.text("privacy.clear_history") : rows[indexPath.row].0
        content.textProperties.color = .systemRed; cell.contentConfiguration = content; return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == rows.count { HistoryStore.shared.clear() }
        else { runtime.clearData(rows[indexPath.row].1) }
        let alert = UIAlertController(title: VulpraL10n.text("privacy.cleared"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: VulpraL10n.text("common.ok"), style: .default)); present(alert, animated: true)
    }
}
