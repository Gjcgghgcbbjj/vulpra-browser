import UIKit

final class SettingsViewController: UITableViewController {
    private enum Row: CaseIterable {
        case searchEngine, remoteSuggestions, darkAppearance, desktopMode,
             pageZoom, trackingProtection, httpsOnly, historyRetention, addons, permissions
    }

    init() { super.init(style: .insetGrouped) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = Row.allCases[indexPath.row]
        let settings = BrowserSettingsStore.shared.value
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        cell.accessoryView = nil
        cell.accessoryType = .disclosureIndicator
        switch row {
        case .searchEngine: content.text = "Search Engine"; content.secondaryText = settings.searchEngine.title
        case .remoteSuggestions: configureSwitch(cell, title: "Search Suggestions", isOn: settings.remoteSuggestions, action: #selector(toggleSuggestions(_:)), content: &content)
        case .darkAppearance: configureSwitch(cell, title: "Dark Appearance", isOn: settings.darkAppearance, action: #selector(toggleDark(_:)), content: &content)
        case .desktopMode: configureSwitch(cell, title: "Desktop Sites by Default", isOn: settings.defaultDesktopMode, action: #selector(toggleDesktop(_:)), content: &content)
        case .pageZoom: content.text = "Page Zoom"; content.secondaryText = "\(settings.pageZoom)%"
        case .trackingProtection: content.text = "Tracking Protection"; content.secondaryText = settings.trackingProtection.rawValue.capitalized
        case .httpsOnly: configureSwitch(cell, title: "HTTPS-Only", isOn: settings.httpsOnly, action: #selector(toggleHTTPS(_:)), content: &content)
        case .historyRetention: content.text = "History Retention"; content.secondaryText = "\(settings.historyRetentionDays) days"
        case .addons: content.text = "Extensions"; content.image = UIImage(systemName: "puzzlepiece.extension")
        case .permissions: content.text = "Site Permissions"; content.image = UIImage(systemName: "hand.raised")
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = Row.allCases[indexPath.row]
        switch row {
        case .searchEngine: choose(title: "Search Engine", values: SearchEngine.allCases, label: { $0.title }) { engine in BrowserSettingsStore.shared.update { $0.searchEngine = engine } }
        case .pageZoom: choose(title: "Page Zoom", values: [75, 90, 100, 110, 125, 150], label: { "\($0)%" }) { zoom in BrowserSettingsStore.shared.update { $0.pageZoom = zoom } }
        case .trackingProtection: choose(title: "Tracking Protection", values: TrackingProtectionLevel.allCases, label: { $0.rawValue.capitalized }) { level in BrowserSettingsStore.shared.update { $0.trackingProtection = level } }
        case .historyRetention: choose(title: "History Retention", values: [7, 30, 90, 365], label: { "\($0) days" }) { days in BrowserSettingsStore.shared.update { $0.historyRetentionDays = days } }
        case .addons: navigationController?.pushViewController(AddonManagementViewController(), animated: true)
        case .permissions: navigationController?.pushViewController(SitePermissionsViewController(), animated: true)
        default: break
        }
    }

    private func configureSwitch(_ cell: UITableViewCell, title: String, isOn: Bool, action: Selector,
                                 content: inout UIListContentConfiguration) {
        content.text = title
        let control = UISwitch(); control.isOn = isOn; control.addTarget(self, action: action, for: .valueChanged)
        cell.accessoryView = control; cell.accessoryType = .none
    }

    private func choose<T>(title: String, values: [T], label: (T) -> String, apply: @escaping (T) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        values.forEach { value in alert.addAction(UIAlertAction(title: label(value), style: .default) { _ in apply(value); self.tableView.reloadData() }) }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func toggleSuggestions(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.remoteSuggestions = sender.isOn } }
    @objc private func toggleDark(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.darkAppearance = sender.isOn }; overrideUserInterfaceStyle = sender.isOn ? .dark : .unspecified }
    @objc private func toggleDesktop(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.defaultDesktopMode = sender.isOn } }
    @objc private func toggleHTTPS(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.httpsOnly = sender.isOn } }
}
