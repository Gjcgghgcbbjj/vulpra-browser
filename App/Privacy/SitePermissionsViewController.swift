import UIKit

final class SitePermissionsViewController: UITableViewController {
    private let emptyState = VulpraEmptyStateView(
        symbol: "checkmark.shield", title: VulpraL10n.text("empty.permissions")
    )

    init() { super.init(style: .insetGrouped) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = VulpraL10n.text("site_permissions.title")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: VulpraL10n.text("common.clear"), style: .plain, target: self, action: #selector(clear))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PermissionCell")
        refresh()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        SitePermissionStore.shared.records.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let record = SitePermissionStore.shared.records[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "PermissionCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = record.host == "This site" ? VulpraL10n.text("permission.this_site") : record.host
        let permission = VulpraL10n.text("permission.kind.\(record.permission)", fallback: record.permission)
        content.secondaryText = VulpraL10n.format("site_permissions.record", permission, record.decision.localizedTitle)
        content.image = UIImage(systemName: record.decision == .allow ? "checkmark.shield" : "xmark.shield")
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        SitePermissionStore.shared.remove(SitePermissionStore.shared.records[indexPath.row])
        refresh()
    }

    @objc private func clear() { SitePermissionStore.shared.clear(); refresh() }

    private func refresh() {
        tableView.reloadData()
        let isEmpty = SitePermissionStore.shared.records.isEmpty
        tableView.backgroundView = isEmpty ? emptyState : nil
        navigationItem.rightBarButtonItem?.isEnabled = !isEmpty
    }
}
