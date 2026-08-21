import UIKit

protocol StartPageViewControllerDelegate: AnyObject {
    func startPage(_ controller: StartPageViewController, open text: String)
    func startPageDidRequestPrivateTab(_ controller: StartPageViewController)
    func startPageDidRequestBookmarks(_ controller: StartPageViewController)
    func startPageDidRequestHistory(_ controller: StartPageViewController)
    func startPageDidRequestDownloads(_ controller: StartPageViewController)
    func startPageDidRequestSettings(_ controller: StartPageViewController)
}

/// Minimal start screen: one search field, one row of site icons, one row of
/// quiet glyph actions. No titles, no tiles, no chrome — content first.
final class StartPageViewController: UIViewController, UITextFieldDelegate {
    weak var delegate: StartPageViewControllerDelegate?
    private let searchField = UITextField()
    private let quickRow = UIStackView()
    private let actionRow = UIStackView()
    private var quickURLs: [URL] = []

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); reloadQuickSites() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        searchField.placeholder = L10n.tr("Search or enter website", "搜索或输入网址")
        searchField.backgroundColor = .secondarySystemBackground
        searchField.layer.cornerRadius = 14
        searchField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        searchField.leftViewMode = .always
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .go
        searchField.keyboardType = .webSearch
        searchField.autocapitalizationType = .none
        searchField.autocorrectionType = .no
        searchField.delegate = self
        searchField.heightAnchor.constraint(equalToConstant: 50).isActive = true

        quickRow.axis = .horizontal
        quickRow.distribution = .fillEqually
        quickRow.spacing = 18

        let actions: [(String, Selector)] = [
            ("star", #selector(bookmarks)),
            ("clock", #selector(history)),
            ("arrow.down.circle", #selector(downloads)),
            ("hand.raised", #selector(privateTab)),
            ("gearshape", #selector(settings)),
        ]
        for (symbol, selector) in actions {
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: symbol,
                                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 21, weight: .medium))
            configuration.baseForegroundColor = .secondaryLabel
            let button = UIButton(configuration: configuration)
            button.addTarget(self, action: selector, for: .touchUpInside)
            actionRow.addArrangedSubview(button)
        }
        actionRow.axis = .horizontal
        actionRow.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [searchField, quickRow, actionRow])
        stack.axis = .vertical
        stack.spacing = 34
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -56),
        ])
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.startPage(self, open: textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }

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
        let unique = Array(pairs.filter { seen.insert($0.1.absoluteString).inserted }.prefix(6))
        quickURLs = unique.map { $0.1 }

        quickRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        quickRow.isHidden = unique.isEmpty
        guard !unique.isEmpty else { return }

        // One quiet row of circular site icons — no text labels.
        for (index, item) in unique.enumerated() {
            let button = UIButton(type: .custom)
            button.setImage(SiteIcon.placeholder(for: item.1, size: 52), for: .normal)
            button.imageView?.contentMode = .scaleAspectFill
            button.layer.cornerRadius = 26
            button.clipsToBounds = true
            button.accessibilityLabel = item.0.isEmpty ? item.1.host : item.0
            button.tag = index
            button.addTarget(self, action: #selector(openQuickSite(_:)), for: .touchUpInside)
            button.widthAnchor.constraint(equalToConstant: 52).isActive = true
            button.heightAnchor.constraint(equalToConstant: 52).isActive = true
            quickRow.addArrangedSubview(button)
            SiteIcon.load(for: item.1) { [weak self, weak button] image in
                guard let self, let button,
                      self.quickURLs.indices.contains(button.tag),
                      self.quickURLs[button.tag] == item.1 else { return }
                button.setImage(image, for: .normal)
            }
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
