import UIKit
import VulpraEngineKit

final class SettingsViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case general, appearance, privacy, data

        var titleKey: String {
            switch self {
            case .general: return "settings.section.general"
            case .appearance: return "settings.section.appearance"
            case .privacy: return "settings.section.privacy"
            case .data: return "settings.section.data"
            }
        }
    }

    private enum Row {
        case searchEngine, remoteSuggestions, desktopMode, darkAppearance, pageZoom
        case trackingProtection, httpsOnly, permissions, historyRetention, privacyData
    }

    private let rows: [Section: [Row]] = [
        .general: [.searchEngine, .remoteSuggestions, .desktopMode],
        .appearance: [.darkAppearance, .pageZoom],
        .privacy: [.trackingProtection, .httpsOnly, .permissions],
        .data: [.historyRetention, .privacyData],
    ]
    private let runtime: any EngineRuntime

    init(runtime: any EngineRuntime) {
        self.runtime = runtime
        super.init(style: .insetGrouped)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = VulpraL10n.text("settings.title")
        tableView.tintColor = VulpraAppearance.accent
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection index: Int) -> String? {
        Section(rawValue: index).map { VulpraL10n.text($0.titleKey) }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection index: Int) -> Int {
        guard let section = Section(rawValue: index) else { return 0 }
        return rows[section]?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = row(at: indexPath)
        let settings = BrowserSettingsStore.shared.value
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.image = UIImage(systemName: symbol(for: row))
        content.imageProperties.tintColor = tint(for: row)
        cell.accessoryView = nil
        cell.accessoryType = .disclosureIndicator
        switch row {
        case .searchEngine:
            content.text = VulpraL10n.text("settings.search_engine"); content.secondaryText = settings.searchEngine.title
        case .remoteSuggestions:
            configureSwitch(cell, title: VulpraL10n.text("settings.search_suggestions"), isOn: settings.remoteSuggestions,
                            action: #selector(toggleSuggestions(_:)), content: &content)
        case .desktopMode:
            configureSwitch(cell, title: VulpraL10n.text("settings.desktop_default"), isOn: settings.defaultDesktopMode,
                            action: #selector(toggleDesktop(_:)), content: &content)
        case .darkAppearance:
            configureSwitch(cell, title: VulpraL10n.text("settings.dark_appearance"), isOn: settings.darkAppearance,
                            action: #selector(toggleDark(_:)), content: &content)
        case .pageZoom:
            content.text = VulpraL10n.text("settings.page_zoom")
            content.secondaryText = VulpraL10n.format("settings.page_zoom.value", settings.pageZoom)
        case .trackingProtection:
            content.text = VulpraL10n.text("settings.tracking_protection")
            content.secondaryText = settings.trackingProtection.localizedTitle
        case .httpsOnly:
            configureSwitch(cell, title: VulpraL10n.text("settings.https_only"), isOn: settings.httpsOnly,
                            action: #selector(toggleHTTPS(_:)), content: &content)
        case .permissions: content.text = VulpraL10n.text("settings.site_permissions")
        case .historyRetention:
            content.text = VulpraL10n.text("settings.history_retention")
            content.secondaryText = VulpraL10n.format("settings.history_days", settings.historyRetentionDays)
        case .privacyData: content.text = VulpraL10n.text("settings.clear_data")
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch row(at: indexPath) {
        case .searchEngine:
            choose(title: VulpraL10n.text("settings.search_engine"), values: SearchEngine.allCases, label: { $0.title }) { engine in
                BrowserSettingsStore.shared.update { $0.searchEngine = engine }
            }
        case .pageZoom:
            choose(title: VulpraL10n.text("settings.page_zoom"), values: [75, 90, 100, 110, 125, 150],
                   label: { VulpraL10n.format("settings.page_zoom.value", $0) }) { value in
                BrowserSettingsStore.shared.update { $0.pageZoom = value }
            }
        case .trackingProtection:
            choose(title: VulpraL10n.text("settings.tracking_protection"), values: TrackingProtectionLevel.allCases,
                   label: { $0.localizedTitle }) { value in
                BrowserSettingsStore.shared.update { $0.trackingProtection = value }
            }
        case .historyRetention:
            choose(title: VulpraL10n.text("settings.history_retention"), values: [7, 30, 90, 365],
                   label: { VulpraL10n.format("settings.history_days", $0) }) { value in
                BrowserSettingsStore.shared.update { $0.historyRetentionDays = value }
            }
        case .privacyData:
            navigationController?.pushViewController(PrivacyDataViewController(runtime: runtime), animated: true)
        case .permissions: navigationController?.pushViewController(SitePermissionsViewController(), animated: true)
        default: break
        }
    }

    private func row(at indexPath: IndexPath) -> Row {
        rows[Section(rawValue: indexPath.section)!]![indexPath.row]
    }

    private func symbol(for row: Row) -> String {
        switch row {
        case .searchEngine: return "magnifyingglass"
        case .remoteSuggestions: return "text.bubble"
        case .desktopMode: return "desktopcomputer"
        case .darkAppearance: return "moon"
        case .pageZoom: return "textformat.size"
        case .trackingProtection: return "shield.lefthalf.filled"
        case .httpsOnly: return "lock"
        case .permissions: return "hand.raised"
        case .historyRetention: return "clock.arrow.circlepath"
        case .privacyData: return "trash"
        }
    }

    private func tint(for row: Row) -> UIColor {
        switch row {
        case .trackingProtection, .httpsOnly, .permissions: return VulpraAppearance.privateAccent
        case .privacyData: return .systemRed
        default: return VulpraAppearance.graphite
        }
    }

    private func configureSwitch(_ cell: UITableViewCell, title: String, isOn: Bool, action: Selector,
                                 content: inout UIListContentConfiguration) {
        content.text = title
        let control = UISwitch()
        control.isOn = isOn
        control.addTarget(self, action: action, for: .valueChanged)
        cell.accessoryView = control
        cell.accessoryType = .none
    }

    private func choose<T>(title: String, values: [T], label: (T) -> String, apply: @escaping (T) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        values.forEach { value in
            alert.addAction(UIAlertAction(title: label(value), style: .default) { _ in
                apply(value); self.tableView.reloadData()
            })
        }
        alert.addAction(UIAlertAction(title: VulpraL10n.text("common.cancel"), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func toggleSuggestions(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.remoteSuggestions = sender.isOn } }
    @objc private func toggleDark(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.darkAppearance = sender.isOn }; overrideUserInterfaceStyle = sender.isOn ? .dark : .unspecified }
    @objc private func toggleDesktop(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.defaultDesktopMode = sender.isOn } }
    @objc private func toggleHTTPS(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.httpsOnly = sender.isOn } }
}
