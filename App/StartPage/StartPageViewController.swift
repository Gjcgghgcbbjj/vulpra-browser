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
        let title = UILabel()
        title.text = "Vulpra"
        title.font = .systemFont(ofSize: 36, weight: .bold)
        title.textAlignment = .center
        searchField.placeholder = "Search or enter website"
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
            action("star", "Bookmarks", #selector(bookmarks)),
            action("clock", "History", #selector(history)),
            action("arrow.down.circle", "Downloads", #selector(downloads)),
            action("hand.raised", "Private", #selector(privateTab)),
            action("gearshape", "Settings", #selector(settings)),
        ]
        let actionStack = UIStackView(arrangedSubviews: actions)
        actionStack.axis = .horizontal
        actionStack.distribution = .fillEqually
        actionStack.spacing = 8
        quickStack.axis = .vertical
        quickStack.spacing = 6
        let stack = UIStackView(arrangedSubviews: [title, searchField, quickStack, actionStack])
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


    private func reloadQuickSites() {
        quickStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
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
        let unique = pairs.filter { seen.insert($0.1.absoluteString).inserted }.prefix(6)
        quickURLs = unique.map { $0.1 }
        unique.enumerated().forEach { index, item in
            var configuration = UIButton.Configuration.gray()
            configuration.title = item.0
            configuration.subtitle = item.1.host
            configuration.image = UIImage(systemName: "globe")
            configuration.imagePadding = 10
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            let button = UIButton(configuration: configuration)
            button.contentHorizontalAlignment = .leading
            button.tag = index
            button.addTarget(self, action: #selector(openQuickSite(_:)), for: .touchUpInside)
            quickStack.addArrangedSubview(button)
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
