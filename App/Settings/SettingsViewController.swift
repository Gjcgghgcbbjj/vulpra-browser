import UIKit

/// iOS-Settings-style grouped layout: tinted glyph per row, four logical
/// sections, explanatory footers.
final class SettingsViewController: UITableViewController {
    private enum Row {
        case searchEngine, remoteSuggestions, desktopMode
        case darkAppearance, pageZoom
        case trackingProtection, httpsOnly, permissions
        case historyRetention, privacyData, addons

        var title: String {
            switch self {
            case .searchEngine: return L10n.tr("Search Engine", "搜索引擎")
            case .remoteSuggestions: return L10n.tr("Search Suggestions", "搜索建议")
            case .desktopMode: return L10n.tr("Desktop Sites by Default", "默认请求桌面版网站")
            case .darkAppearance: return L10n.tr("Dark Appearance", "深色外观")
            case .pageZoom: return L10n.tr("Page Zoom", "页面缩放")
            case .trackingProtection: return L10n.tr("Tracking Protection", "跟踪保护")
            case .httpsOnly: return L10n.tr("HTTPS-Only", "仅 HTTPS 模式")
            case .permissions: return L10n.tr("Site Permissions", "网站权限")
            case .historyRetention: return L10n.tr("History Retention", "历史保留")
            case .privacyData: return L10n.tr("Clear Browsing Data", "清除浏览数据")
            case .addons: return L10n.tr("Extensions", "扩展")
            }
        }

        var symbol: String { 
            switch self {
            case .searchEngine: return "magnifyingglass"
            case .remoteSuggestions: return "text.magnifyingglass"
            case .desktopMode: return "desktopcomputer"
            case .darkAppearance: return "moon.fill"
            case .pageZoom: return "plus.magnifyingglass"
            case .trackingProtection: return "shield.lefthalf.filled"
            case .httpsOnly: return "lock.shield"
            case .permissions: return "hand.raised"
            case .historyRetention: return "clock.arrow.circlepath"
            case .privacyData: return "trash"
            case .addons: return "puzzlepiece.extension"
            }
        }

        var tint: UIColor {
            switch self {
            case .searchEngine, .remoteSuggestions: return .systemBlue
            case .desktopMode, .pageZoom: return .systemIndigo
            case .darkAppearance: return .systemPurple
            case .trackingProtection, .httpsOnly: return .systemGreen
            case .permissions: return .systemOrange
            case .historyRetention, .privacyData: return .systemRed
            case .addons: return .systemTeal
            }
        }
    }

    private struct Section {
        let header: String
        let footer: String?
        let rows: [Row]

        static let all: [Section] = [
            Section(header: L10n.tr("General", "通用"), footer: nil,
                    rows: [.searchEngine, .remoteSuggestions, .desktopMode]),
            Section(header: L10n.tr("Appearance", "外观"), footer: nil,
                    rows: [.darkAppearance, .pageZoom]),
            Section(header: L10n.tr("Privacy & Security", "隐私与安全"),
                    footer: L10n.tr("Tracking protection blocks known trackers before pages load.",
                                    "跟踪保护会在页面加载前拦截已知跟踪器。"),
                    rows: [.trackingProtection, .httpsOnly, .permissions]),
            Section(header: L10n.tr("Data & Extensions", "数据与扩展"), footer: nil,
                    rows: [.historyRetention, .privacyData, .addons]),
        ]
    }

    init() { super.init(style: .insetGrouped) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("Settings", "设置")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
    }

    // MARK: - Table data

    override func numberOfSections(in tableView: UITableView) -> Int { Section.all.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section.all[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section.all[section].header
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        Section.all[section].footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = Section.all[indexPath.section].rows[indexPath.row]
        let settings = BrowserSettingsStore.shared.value
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.image = UIImage(systemName: row.symbol)
        content.imageProperties.tintColor = row.tint
        content.imageProperties.maximumSize = CGSize(width: 26, height: 26)
        content.preferredConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        cell.accessoryView = nil
        switch row {
        case .remoteSuggestions:
            configureSwitch(cell, isOn: settings.remoteSuggestions, action: #selector(toggleSuggestions(_:)), content: &content)
        case .darkAppearance:
            configureSwitch(cell, isOn: settings.darkAppearance, action: #selector(toggleDark(_:)), content: &content)
        case .desktopMode:
            configureSwitch(cell, isOn: settings.defaultDesktopMode, action: #selector(toggleDesktop(_:)), content: &content)
        case .httpsOnly:
            configureSwitch(cell, isOn: settings.httpsOnly, action: #selector(toggleHTTPS(_:)), content: &content)
        case .searchEngine:
            content.secondaryText = settings.searchEngine.title
            cell.accessoryType = .disclosureIndicator
        case .pageZoom:
            content.secondaryText = "\(settings.pageZoom)%"
            cell.accessoryType = .disclosureIndicator
        case .trackingProtection:
            content.secondaryText = settings.trackingProtection.rawValue.capitalized
            cell.accessoryType = .disclosureIndicator
        case .historyRetention:
            content.secondaryText = "\(settings.historyRetentionDays)" + L10n.tr(" days", " 天")
            cell.accessoryType = .disclosureIndicator
        case .privacyData, .addons, .permissions:
            cell.accessoryType = .disclosureIndicator
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = Section.all[indexPath.section].rows[indexPath.row]
        switch row {
        case .searchEngine:
            choose(title: L10n.tr("Search Engine", "搜索引擎"), values: SearchEngine.allCases,
                   label: { $0.title }) { engine in BrowserSettingsStore.shared.update { $0.searchEngine = engine } }
        case .pageZoom:
            choose(title: L10n.tr("Page Zoom", "页面缩放"), values: [75, 90, 100, 110, 125, 150],
                   label: { "\($0)%" }) { zoom in BrowserSettingsStore.shared.update { $0.pageZoom = zoom } }
        case .trackingProtection:
            choose(title: L10n.tr("Tracking Protection", "跟踪保护"), values: TrackingProtectionLevel.allCases,
                   label: { $0.rawValue.capitalized }) { level in BrowserSettingsStore.shared.update { $0.trackingProtection = level } }
        case .historyRetention:
            choose(title: L10n.tr("History Retention", "历史保留"), values: [7, 30, 90, 365],
                   label: { "\($0)" + L10n.tr(" days", " 天") }) { days in BrowserSettingsStore.shared.update { $0.historyRetentionDays = days } }
        case .privacyData:
            navigationController?.pushViewController(PrivacyDataViewController(), animated: true)
        case .addons:
            navigationController?.pushViewController(AddonManagementViewController(), animated: true)
        case .permissions:
            navigationController?.pushViewController(SitePermissionsViewController(), animated: true)
        default:
            break
        }
        tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
    }

    private func configureSwitch(_ cell: UITableViewCell, isOn: Bool, action: Selector,
                                 content: inout UIListContentConfiguration) {
        let control = UISwitch(); control.isOn = isOn; control.addTarget(self, action: action, for: .valueChanged)
        cell.accessoryView = control; cell.accessoryType = .none
    }

    private func choose<T>(title: String, values: [T], label: (T) -> String, apply: @escaping (T) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        values.forEach { value in alert.addAction(UIAlertAction(title: label(value), style: .default) { _ in apply(value) }) }
        alert.addAction(UIAlertAction(title: L10n.tr("Cancel", "取消"), style: .cancel))
        present(alert, animated: true)
    }

    @objc private func toggleSuggestions(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.remoteSuggestions = sender.isOn } }
    @objc private func toggleDark(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.darkAppearance = sender.isOn }; overrideUserInterfaceStyle = sender.isOn ? .dark : .unspecified }
    @objc private func toggleDesktop(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.defaultDesktopMode = sender.isOn } }
    @objc private func toggleHTTPS(_ sender: UISwitch) { BrowserSettingsStore.shared.update { $0.httpsOnly = sender.isOn } }
}
