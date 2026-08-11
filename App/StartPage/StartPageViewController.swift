import UIKit

protocol StartPageViewControllerDelegate: AnyObject {
    func startPage(_ controller: StartPageViewController, open text: String)
    func startPageDidRequestPrivateTab(_ controller: StartPageViewController)
    func startPageDidRequestBookmarks(_ controller: StartPageViewController)
    func startPageDidRequestHistory(_ controller: StartPageViewController)
    func startPageDidRequestDownloads(_ controller: StartPageViewController)
    func startPageDidRequestSettings(_ controller: StartPageViewController)
}

final class StartPageViewController: UIViewController {
    weak var delegate: StartPageViewControllerDelegate?
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let quickSection = UIStackView()
    private let quickGrid = UIStackView()
    private let actionGrid = UIStackView()
    private var quickItems: [(String, URL)] = []
    private var quickURLs: [URL] = []
    private weak var jitLabel: UILabel?
    private var renderedColumns = 0

    private var jitRefreshTimer: Timer?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadQuickSites()
        refreshJITFooter()
        jitRefreshTimer?.invalidate()
        jitRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshJITFooter()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        jitRefreshTimer?.invalidate()
        jitRefreshTimer = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = VulpraAppearance.porcelain
        configureLayout()
        configureActions()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let columns = traitCollection.horizontalSizeClass == .regular || view.bounds.width >= 600 ? 3 : 2
        guard columns != renderedColumns else { return }
        renderedColumns = columns
        renderQuickGrid(columns: columns)
    }

    private func configureLayout() {
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset.bottom = 126
        scrollView.verticalScrollIndicatorInsets.bottom = 126
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let mark = VulpraBrandMarkView()
        mark.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mark.widthAnchor.constraint(equalToConstant: 42),
            mark.heightAnchor.constraint(equalToConstant: 42),
        ])
        let title = UILabel()
        title.text = "Vulpra"
        title.font = .preferredFont(forTextStyle: .title2)
        title.textColor = VulpraAppearance.graphite
        title.textAlignment = .center
        let brand = UIStackView(arrangedSubviews: [mark, title])
        brand.axis = .horizontal
        brand.alignment = .center
        brand.spacing = 10
        brand.translatesAutoresizingMaskIntoConstraints = false
        let brandContainer = UIView()
        brandContainer.addSubview(brand)
        NSLayoutConstraint.activate([
            brand.topAnchor.constraint(equalTo: brandContainer.topAnchor),
            brand.centerXAnchor.constraint(equalTo: brandContainer.centerXAnchor),
            brand.bottomAnchor.constraint(equalTo: brandContainer.bottomAnchor),
        ])

        quickSection.axis = .vertical
        quickSection.spacing = 12
        let quickTitle = UILabel()
        quickTitle.text = VulpraL10n.text("start.quick_sites")
        quickTitle.font = .preferredFont(forTextStyle: .headline)
        quickSection.addArrangedSubview(quickTitle)
        quickSection.addArrangedSubview(quickGrid)
        quickGrid.axis = .vertical
        quickGrid.spacing = 10

        actionGrid.axis = .horizontal
        actionGrid.distribution = .fillEqually
        actionGrid.alignment = .top
        actionGrid.spacing = 2
        contentStack.addArrangedSubview(brandContainer)
        contentStack.addArrangedSubview(actionGrid)
        contentStack.addArrangedSubview(quickSection)

        let jitLabel = UILabel()
        self.jitLabel = jitLabel
        jitLabel.text = VulpraJitProbe.footerText
        jitLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        jitLabel.textColor = .secondaryLabel
        jitLabel.textAlignment = .center
        jitLabel.numberOfLines = 0
        jitLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(jitLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 48),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func refreshJITFooter() {
        jitLabel?.text = VulpraJitProbe.footerText
    }

    private func configureActions() {
        let actionSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let actions = [
            ("star", "start.bookmarks", #selector(bookmarks)),
            ("clock", "start.history", #selector(history)),
            ("arrow.down.circle", "start.downloads", #selector(downloads)),
            ("hand.raised", "start.private", #selector(privateTab)),
            ("gearshape", "start.settings", #selector(settings)),
        ]
        actions.forEach { symbol, key, selector in
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: symbol)
            configuration.preferredSymbolConfigurationForImage = actionSymbolConfiguration
            var title = AttributedString(VulpraL10n.text(key))
            title.font = .preferredFont(forTextStyle: .caption1)
            configuration.attributedTitle = title
            configuration.imagePlacement = .top
            configuration.imagePadding = 7
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 1, bottom: 6, trailing: 1)
            let button = UIButton(configuration: configuration)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.tintColor = key == "start.private" ? VulpraAppearance.privateAccent : VulpraAppearance.graphite
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
            button.addTarget(self, action: selector, for: .touchUpInside)
            actionGrid.addArrangedSubview(button)
        }
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
        quickItems = Array(pairs.filter { seen.insert($0.1.absoluteString).inserted }.prefix(6))
        quickURLs = quickItems.map(\.1)
        quickSection.isHidden = quickItems.isEmpty
        renderQuickGrid(columns: max(renderedColumns, 2))
    }

    private func renderQuickGrid(columns: Int) {
        quickGrid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !quickItems.isEmpty else { return }
        for start in stride(from: 0, to: quickItems.count, by: columns) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 10
            for index in start..<min(start + columns, quickItems.count) { row.addArrangedSubview(quickButton(at: index)) }
            while row.arrangedSubviews.count < columns { row.addArrangedSubview(UIView()) }
            quickGrid.addArrangedSubview(row)
        }
    }

    private func quickButton(at index: Int) -> UIButton {
        let item = quickItems[index]
        var configuration = UIButton.Configuration.gray()
        configuration.title = item.0
        configuration.subtitle = item.1.host
        configuration.image = UIImage(systemName: "globe")
        configuration.imagePadding = 8
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = VulpraAppearance.itemRadius
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        let button = UIButton(configuration: configuration)
        button.contentHorizontalAlignment = .leading
        button.tag = index
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 62).isActive = true
        button.addTarget(self, action: #selector(openQuickSite(_:)), for: .touchUpInside)
        return button
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
