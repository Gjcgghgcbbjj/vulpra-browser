import UIKit

protocol StartPageViewControllerDelegate: AnyObject {
    func startPage(_ controller: StartPageViewController, open text: String)
    func startPageDidRequestPrivateTab(_ controller: StartPageViewController)
    func startPageDidRequestBookmarks(_ controller: StartPageViewController)
    func startPageDidRequestHistory(_ controller: StartPageViewController)
    func startPageDidRequestDownloads(_ controller: StartPageViewController)
    func startPageDidRequestSettings(_ controller: StartPageViewController)
}

/// A calm spatial home: large typography, one command field, and quiet cards.
final class StartPageViewController: UIViewController, UITextFieldDelegate {
    weak var delegate: StartPageViewControllerDelegate?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let gradient = CAGradientLayer()
    private let shortcutGrid = UIStackView()
    private let recentStack = UIStackView()
    private let recentHeader = UILabel()
    private let pinnedHeader = UILabel()
    private let emptyHint = UILabel()

    private let brandLabel: UILabel = {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: "VULPRA", attributes: [
            .font: UIFont.preferredFont(forTextStyle: .footnote),
            .foregroundColor: UIColor.secondaryLabel,
            .kern: 4,
        ])
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var brandRow: UIStackView = {
        let row = UIStackView(arrangedSubviews: [VulpraAppearance.logoMark(size: 10), brandLabel])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }()

    private let greetingLabel: UILabel = {
        let label = UILabel()
        // SF Rounded for the hero — the single highest-leverage "designed"
        // signal on the home screen.
        let base = UIFont.systemFont(ofSize: 40, weight: .bold)
        let rounded: UIFont
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            rounded = UIFont(descriptor: descriptor, size: base.pointSize)
        } else {
            rounded = base
        }
        label.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: rounded)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private let contextLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        return label
    }()

    private let searchField: UITextField = {
        let field = UITextField()
        field.placeholder = L10n.tr("Search or enter website", "搜索或输入网址")
        field.backgroundColor = VulpraAppearance.surfaceElevated
        field.font = .preferredFont(forTextStyle: .body)
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .go
        field.keyboardType = .webSearch
        field.autocapitalizationType = .none
        field.autocorrectionType = .no

        // Magnifier sits in a soft ember-tinted disc — a small deliberate
        // accent instead of a bare gray glyph.
        let disc = UIView(frame: CGRect(x: 0, y: 0, width: 46, height: 34))
        let discView = UIView(frame: CGRect(x: 10, y: 3, width: 28, height: 28))
        discView.backgroundColor = VulpraAppearance.mutedAccent
        discView.layer.cornerCurve = .continuous
        discView.layer.cornerRadius = 9.5
        discView.isUserInteractionEnabled = false
        let magnifier = UIImageView(image: UIImage(systemName: "magnifyingglass",
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        magnifier.tintColor = VulpraAppearance.accent
        magnifier.contentMode = .center
        magnifier.frame = discView.bounds
        discView.addSubview(magnifier)
        disc.addSubview(discView)
        field.leftView = disc
        field.leftViewMode = .always
        let rightPad = UIView(frame: CGRect(x: 0, y: 0, width: 18, height: 1))
        field.rightView = rightPad
        field.rightViewMode = .always
        VulpraAppearance.elevate(field, radius: VulpraAppearance.Radius.field)
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true
        return field
    }()

    private let menuButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "ellipsis.circle.fill")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .title2)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        let button = UIButton(type: .system)
        button.configuration = configuration
        button.tintColor = .secondaryLabel
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = L10n.tr("Browser library", "浏览器资料库")
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        refreshGreeting()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadLinks()
    }

    override func viewDidLayoutSubviews() {
        gradient.frame = view.bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateGradientColors()
            searchField.layer.borderColor = VulpraAppearance.hairline.resolvedColor(with: traitCollection).cgColor
        }
    }

    private func configure() {
        view.backgroundColor = .systemBackground
        updateGradientColors()
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        view.layer.insertSublayer(gradient, at: 0)

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        configureMenu()
        // The spacer must be the single stretchiest element, or the header
        // collapses to the right on some stack distributions (observed on
        // iOS 26: brand and menu bunched at trailing).
        let headerSpacer = UIView()
        headerSpacer.setContentHuggingPriority(UILayoutPriority(249), for: .horizontal)
        headerSpacer.setContentCompressionResistancePriority(UILayoutPriority(749), for: .horizontal)
        let header = UIStackView(arrangedSubviews: [brandRow, headerSpacer, menuButton])
        header.alignment = .center

        refreshGreeting()
        let hero = UIStackView(arrangedSubviews: [greetingLabel, contextLabel])
        hero.axis = .vertical
        hero.spacing = 5
        hero.setCustomSpacing(22, after: contextLabel)

        recentHeader.attributedText = sectionHeader(L10n.tr("Recent", "最近访问")).attributedText
        recentHeader.isHidden = true
        shortcutGrid.axis = .vertical
        shortcutGrid.spacing = 12
        recentStack.axis = .vertical
        recentStack.spacing = 10
        emptyHint.text = L10n.tr("Pin a site and it will live here.", "固定网站后，它会出现在这里。")
        emptyHint.font = .preferredFont(forTextStyle: .callout)
        emptyHint.textColor = .tertiaryLabel
        emptyHint.textAlignment = .center
        emptyHint.numberOfLines = 0

        contentStack.addArrangedSubview(header)
        contentStack.addArrangedSubview(hero)
        contentStack.addArrangedSubview(searchField)
        pinnedHeader.attributedText = sectionHeader(L10n.tr("Pinned", "固定站点")).attributedText
        contentStack.addArrangedSubview(pinnedHeader)
        contentStack.addArrangedSubview(shortcutGrid)
        contentStack.addArrangedSubview(recentHeader)
        contentStack.addArrangedSubview(recentStack)
        contentStack.addArrangedSubview(emptyHint)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 22),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -22),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -36),
            // Pin the width to the visible frame explicitly: on some iOS 26
            // builds the contentLayoutGuide trailing edge fails to stretch
            // stack children, collapsing the whole home column to intrinsic
            // width (~59% of screen). The frame pin is unconditional.
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -44),

            menuButton.widthAnchor.constraint(equalToConstant: 40),
        ])
        searchField.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPlayedEntrance else { return }
        hasPlayedEntrance = true
        VulpraMotion.entrance([brandLabel, greetingLabel, contextLabel, searchField, menuButton],
                              baseOffset: 16, step: 0.06)
    }
    private var hasPlayedEntrance = false

    private func configureMenu() {
        let privateTab = UIAction(title: L10n.tr("New Private Tab", "新建私密标签页"),
                                  image: UIImage(systemName: "eyeglasses")) { [weak self] _ in
            guard let self else { return }
            self.delegate?.startPageDidRequestPrivateTab(self)
        }
        let bookmark = UIAction(title: L10n.tr("Bookmarks", "书签"), image: UIImage(systemName: "book")) { [weak self] _ in
            guard let self else { return }
            self.delegate?.startPageDidRequestBookmarks(self)
        }
        let history = UIAction(title: L10n.tr("History", "历史记录"), image: UIImage(systemName: "clock.arrow.circlepath")) { [weak self] _ in
            guard let self else { return }
            self.delegate?.startPageDidRequestHistory(self)
        }
        let downloads = UIAction(title: L10n.tr("Downloads", "下载"), image: UIImage(systemName: "arrow.down.circle")) { [weak self] _ in
            guard let self else { return }
            self.delegate?.startPageDidRequestDownloads(self)
        }
        let settings = UIAction(title: L10n.tr("Settings", "设置"), image: UIImage(systemName: "gearshape")) { [weak self] _ in
            guard let self else { return }
            self.delegate?.startPageDidRequestSettings(self)
        }
        menuButton.menu = UIMenu(children: [
            privateTab,
            UIMenu(options: .displayInline, children: [bookmark, history, downloads]),
            UIMenu(options: .displayInline, children: [settings]),
        ])
    }

    private func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return L10n.tr("Good morning", "早上好")
        case 12..<18: return L10n.tr("Good afternoon", "下午好")
        default: return L10n.tr("Good evening", "晚上好")
        }
    }

    private func refreshGreeting() {
        greetingLabel.text = greeting()
        // Speak one language: the UI ships Chinese-first (see L10n), so the
        // date must follow the UI language, not the raw device locale —
        // otherwise the hero mixes scripts on non-Chinese devices.
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        contextLabel.text = formatter.string(from: Date())
    }

    private func sectionHeader(_ title: String) -> UILabel {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption2)
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]])
        let label = UILabel()
        label.attributedText = NSAttributedString(string: title.uppercased(), attributes: [
            .font: UIFontMetrics(forTextStyle: .caption2).scaledFont(
                for: UIFont(descriptor: descriptor, size: 12)),
            .foregroundColor: UIColor.tertiaryLabel,
            .kern: 1.2,
        ])
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func reloadLinks() {
        let bookmarks = BookmarkStore.shared.items.prefix(6).compactMap { item -> (String, URL)? in
            guard !item.isFolder, let value = item.url, let url = URL(string: value) else { return nil }
            return (item.title.isEmpty ? (url.host ?? "") : item.title, url)
        }
        var seen = Set(BookmarkStore.shared.items.compactMap(\.url))
        let uniqueBookmarks = bookmarks.filter { seen.insert($0.1.absoluteString).inserted }

        let visits = HistoryStore.shared.visits.prefix(30).compactMap { visit -> (String, URL)? in
            guard let url = URL(string: visit.url) else { return nil }
            return (visit.title.isEmpty ? (url.host ?? "") : visit.title, url)
        }
        let uniqueVisits = Array(visits.filter { seen.insert($0.1.absoluteString).inserted }.prefix(3))

        rebuildCards(uniqueBookmarks, into: shortcutGrid, style: .pinned)
        rebuildCards(uniqueVisits, into: recentStack, style: .recent)
        let hasShortcuts = !uniqueBookmarks.isEmpty
        shortcutGrid.isHidden = !hasShortcuts
        pinnedHeader.isHidden = !hasShortcuts
        emptyHint.isHidden = hasShortcuts
        recentHeader.isHidden = uniqueVisits.isEmpty
    }

    private func rebuildCards(_ pairs: [(String, URL)], into stack: UIStackView, style: StartPageCardStyle) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !pairs.isEmpty else { return }
        let columns = style == .pinned ? 2 : 1
        var index = 0
        while index < pairs.count {
            let row = UIStackView(arrangedSubviews: [])
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 12
            for _ in 0..<columns {
                if index < pairs.count {
                    let pair = pairs[index]
                    row.addArrangedSubview(StartPageLinkCard(title: pair.0, url: pair.1, style: style) { [weak self] url in
                        self?.delegate?.startPage(self!, open: url.absoluteString)
                    })
                } else {
                    row.addArrangedSubview(UIView())
                }
                index += 1
            }
            stack.addArrangedSubview(row)
        }
    }

    private func updateGradientColors() {
        // Warm breath at the very top, clean middle, soft base — the ember
        // tint stays subliminal but keeps the home from reading as flat white.
        gradient.colors = [
            VulpraAppearance.accent.withAlphaComponent(0.05).cgColor,
            UIColor.systemBackground.cgColor,
            UIColor.secondarySystemBackground.withAlphaComponent(0.5).cgColor,
        ]
        gradient.locations = [0, 0.28, 1]
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        fieldFocus(true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        fieldFocus(false)
    }

    private func fieldFocus(_ active: Bool) {
        searchField.layer.borderColor = active
            ? VulpraAppearance.accent.resolvedColor(with: traitCollection).cgColor
            : VulpraAppearance.hairline.resolvedColor(with: traitCollection).cgColor
        VulpraMotion.spring(damping: 0.8, duration: 0.32) {
            self.searchField.transform = active ? CGAffineTransform(scaleX: 0.99, y: 0.99) : .identity
        }
        // Shadow layers don't participate in UIView animation blocks; swap
        // the glow explicitly (it reads as instant, which suits focus).
        VulpraAppearance.applyFocusGlow(searchField, active: active)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.startPage(self, open: textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }
}
