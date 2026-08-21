import UIKit

protocol StartPageViewControllerDelegate: AnyObject {
    func startPage(_ controller: StartPageViewController, open text: String)
    func startPageDidRequestPrivateTab(_ controller: StartPageViewController)
    func startPageDidRequestBookmarks(_ controller: StartPageViewController)
    func startPageDidRequestHistory(_ controller: StartPageViewController)
    func startPageDidRequestDownloads(_ controller: StartPageViewController)
    func startPageDidRequestSettings(_ controller: StartPageViewController)
}

final class StartPageViewController: UIViewController, UITextFieldDelegate {
    weak var delegate: StartPageViewControllerDelegate?
    private let searchField = UITextField()
    private let quickStack = UIStackView()
    private var quickURLs: [URL] = []

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); reloadQuickSites() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // Subtle brand gradient at the top gives the page depth without
        // fighting dark mode.
        let gradient = CAGradientLayer()
        gradient.colors = [
            VulpraAppearance.accent.withAlphaComponent(0.10).cgColor,
            UIColor.clear.cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        let backdrop = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 260))
        backdrop.autoresizingMask = [.flexibleWidth]
        backdrop.isUserInteractionEnabled = false
        backdrop.layer.addSublayer(gradient)
        gradient.frame = backdrop.bounds
        view.addSubview(backdrop)

        let title = UILabel()
        title.text = "Vulpra"
        title.font = .systemFont(ofSize: 40, weight: .bold)
        title.textAlignment = .center
        let subtitle = UILabel()
        subtitle.text = L10n.tr("Browse with Gecko", "Gecko 内核浏览器")
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.textColor = .secondaryLabel
        subtitle.textAlignment = .center
        searchField.placeholder = L10n.tr("Search or enter website", "搜索或输入网址")
        searchField.backgroundColor = .secondarySystemBackground
        searchField.layer.cornerRadius = 16
        searchField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        searchField.leftViewMode = .always
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .go
        searchField.keyboardType = .webSearch
        searchField.autocapitalizationType = .none
        searchField.autocorrectionType = .no
        searchField.delegate = self
        searchField.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let actions = [
            action("star", L10n.tr("Bookmarks", "书签"), #selector(bookmarks)),
            action("clock", L10n.tr("History", "历史"), #selector(history)),
            action("arrow.down.circle", L10n.tr("Downloads", "下载"), #selector(downloads)),
            action("hand.raised", L10n.tr("Private", "隐私"), #selector(privateTab)),
            action("gearshape", L10n.tr("Settings", "设置"), #selector(settings)),
        ]
        let actionStack = UIStackView(arrangedSubviews: actions)
        actionStack.axis = .horizontal
        actionStack.distribution = .fillEqually
        actionStack.spacing = 8
        quickStack.axis = .vertical
        quickStack.spacing = 6
        let stack = UIStackView(arrangedSubviews: [title, subtitle, searchField, quickStack, actionStack])
        stack.setCustomSpacing(2, after: title)
        stack.setCustomSpacing(28, after: searchField)
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
        ])
    }

    private func action(_ symbol: String, _ title: String, _ selector: Selector) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol)
        configuration.title = title
        configuration.imagePlacement = .top
        configuration.imagePadding = 6
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.startPage(self, open: textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }


    private var quickButtons: [UIButton] = []

    private func reloadQuickSites() {
        let settings = BrowserSettingsStore.shared.value
        var pairs: [(String, URL)] = []
        if settings.showFavorites {
            pairs += BookmarkStore.shared.items.prefix(4).compactMap { item in
                guard !item.isFolder, let value = item.url, let url = URL(string: value) else { return nil }
                return (item.title, url)
            }
        }
        if settings.showRecentVisits {
            pairs += HistoryStore.shared.visits.prefix(4).compactMap { visit in
                URL(string: visit.url).map { (visit.title, $0) }
            }
        }
        var seen = Set<String>()
        let unique = Array(pairs.filter { seen.insert($0.1.absoluteString).inserted }.prefix(8))
        quickURLs = unique.map { $0.1 }

        // Icon grid (4 per row, like mainstream mobile browsers). The set is
        // bounded to 8 items and only rebuilt on viewWillAppear, so a plain
        // rebuild here is cheaper than diffing stack rows.
        quickStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        quickButtons.removeAll()
        guard !unique.isEmpty else { return }

        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "globe")
        configuration.imagePlacement = .top
        configuration.imagePadding = 6
        configuration.preferredSymbolConfigurationForImage =
            UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        configuration.baseForegroundColor = VulpraAppearance.accent
        configuration.titlePadding = 2

        for rowStart in stride(from: 0, to: unique.count, by: 4) {
            let rowItems = unique[rowStart..<min(rowStart + 4, unique.count)]
            var cells: [UIButton] = []
            for (offset, item) in rowItems.enumerated() {
                var cellConfiguration = configuration
                cellConfiguration.title = item.0.isEmpty ? item.1.host ?? "—" : item.0
                let button = UIButton(configuration: cellConfiguration)
                button.tag = rowStart + offset
                button.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
                button.titleLabel?.lineBreakMode = .byTruncatingTail
                button.addTarget(self, action: #selector(openQuickSite(_:)), for: .touchUpInside)
                quickButtons.append(button)
                cells.append(button)
            }
            while cells.count < 4 { cells.append(UIView()) } // pad the last row
            let row = UIStackView(arrangedSubviews: cells)
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 8
            quickStack.addArrangedSubview(row)
        }
    }

    @objc private func openQuickSite(_ sender: UIButton) {
        guard quickURLs.indices.contains(sender.tag) else { return }
        delegate?.startPage(self, open: quickURLs[sender.tag].absoluteString)
    }

    @objc private func privateTab() { delegate?.startPageDidRequestPrivateTab(self) }
    @objc private func bookmarks() { delegate?.startPageDidRequestBookmarks(self) }
    @objc private func history() { delegate?.startPageDidRequestHistory(self) }
    @objc private func downloads() { delegate?.startPageDidRequestDownloads(self) }
    @objc private func settings() { delegate?.startPageDidRequestSettings(self) }
}
