import UIKit

final class SitePermissionsViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Site Permissions"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clear))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PermissionCell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        SitePermissionStore.shared.records.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let record = SitePermissionStore.shared.records[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "PermissionCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = record.host
        content.secondaryText = "\(record.permission) · \(record.decision.rawValue)"
        content.image = UIImage(systemName: record.decision == .allow ? "checkmark.shield" : "xmark.shield")
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        SitePermissionStore.shared.remove(SitePermissionStore.shared.records[indexPath.row])
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    @objc private func clear() { SitePermissionStore.shared.clear(); tableView.reloadData() }
}
