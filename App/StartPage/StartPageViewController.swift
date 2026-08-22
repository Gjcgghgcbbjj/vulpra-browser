import UIKit

protocol StartPageViewControllerDelegate: AnyObject {
    func startPage(_ controller: StartPageViewController, open text: String)
    func startPageDidRequestPrivateTab(_ controller: StartPageViewController)
    func startPageDidRequestBookmarks(_ controller: StartPageViewController)
    func startPageDidRequestHistory(_ controller: StartPageViewController)
    func startPageDidRequestDownloads(_ controller: StartPageViewController)
    func startPageDidRequestSettings(_ controller: StartPageViewController)
}

/// Via-style start screen: centered search capsule, a compact grid of small
/// labelled shortcut tiles (favorites only — history never clutters home),
/// and one quiet glyph row. No thumbnails anywhere.
final class StartPageViewController: UIViewController, UITextFieldDelegate {
    weak var delegate: StartPageViewControllerDelegate?
    private let wallpaperView = UIImageView()
    private let searchField = UITextField()
    private let gridStack = UIStackView()
    private let actionRow = UIStackView()
    private var quickURLs: [URL] = []
    private let columns = 5
    private let tileSize: CGFloat = 40

    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); applyWallpaper(); reloadQuickSites() }

    @objc private func wallpaperDidChange() { applyWallpaper() }

    private func applyWallpaper() {
        let option = Wallpaper(rawValue: BrowserSettingsStore.shared.value.wallpaper) ?? .none
        // Re-measure once layout has settled so gradients/photos render full-size.
        view.layoutIfNeeded()
        let size = view.bounds.size == .zero ? UIScreen.main.bounds.size : view.bounds.size
        wallpaperView.image = option.image(for: size)
        wallpaperView.isHidden = wallpaperView.image == nil
        let dark = option.isDark && wallpaperView.image != nil
        view.backgroundColor = dark ? .black : .systemBackground
        // Flip the whole content tree to dark semantics over dark wallpapers —
        // labels, materials and separators all adapt in one move.
        view.overrideUserInterfaceStyle = dark ? .dark : .unspecified
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyWallpaper()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Via-style wallpaper behind everything; content keeps blur materials.
        wallpaperView.contentMode = .scaleAspectFill
        wallpaperView.clipsToBounds = true
        wallpaperView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(wallpaperView, at: 0)
        NSLayoutConstraint.activate([
            wallpaperView.topAnchor.constraint(equalTo: view.topAnchor),
            wallpaperView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            wallpaperView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wallpaperView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        NotificationCenter.default.addObserver(
            self, selector: #selector(wallpaperDidChange),
            name: .vulpraWallpaperDidChange, object: nil)

        searchField.placeholder = L10n.tr("Search or enter website", "搜索或输入网址")
        // Translucent so a chosen wallpaper glows through; still readable.
        searchField.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.72)
        searchField.layer.cornerRadius = 12
        searchField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        searchField.leftViewMode = .always
        searchField.clearButtonMode = .whileEditing
        searchField.returnKeyType = .go
        searchField.keyboardType = .webSearch
        searchField.autocapitalizationType = .none
        searchField.autocorrectionType = .no
        searchField.delegate = self
        searchField.heightAnchor.constraint(equalToConstant: 44).isActive = true

        gridStack.axis = .vertical
        gridStack.spacing = 18
        gridStack.isHidden = true

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

        let stack = UIStackView(arrangedSubviews: [searchField, gridStack, actionRow])
        stack.axis = .vertical
        stack.spacing = 30
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

    // MARK: - Shortcut grid (Via style)

    /// Favorites only. Recent history stays out of the home screen on purpose:
    /// short visits with missing favicons read as noise, not shortcuts.
    private func reloadQuickSites() {
        let settings = BrowserSettingsStore.shared.value
        var pairs: [(String, URL)] = []
        if settings.showFavorites {
            pairs += BookmarkStore.shared.items.prefix(columns * 2).compactMap { item in
                guard !item.isFolder, let value = item.url, let url = URL(string: value) else { return nil }
                return (item.title.isEmpty ? (url.host ?? "") : item.title, url)
            }
        }
        var seen = Set<String>()
        let unique = pairs.filter { seen.insert($0.1.absoluteString).inserted }
        quickURLs = unique.map { $0.1 }

        gridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        gridStack.isHidden = unique.isEmpty
        guard !unique.isEmpty else { return }

        var index = 0
        while index < unique.count {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            for _ in 0..<columns {
                if index < unique.count {
                    row.addArrangedSubview(makeTile(title: unique[index].0, url: unique[index].1, tag: index))
                } else {
                    let filler = UIView()
                    filler.isUserInteractionEnabled = false
                    row.addArrangedSubview(filler)
                }
                index += 1
            }
            gridStack.addArrangedSubview(row)
        }
    }

    private func makeTile(title: String, url: URL, tag: Int) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 5

        let icon = UIImageView(image: SiteIcon.tile(for: url, size: tileSize, cornerRadius: 9))
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: tileSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: tileSize).isActive = true

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail

        container.addArrangedSubview(icon)
        container.addArrangedSubview(label)

        let button = UIButton(type: .custom)
        button.accessibilityLabel = title
        button.tag = tag
        button.addTarget(self, action: #selector(openQuickSite(_:)), for: .touchUpInside)
        button.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: button.topAnchor),
            container.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: button.leadingAnchor, constant: 2),
            container.trailingAnchor.constraint(lessThanOrEqualTo: button.trailingAnchor, constant: -2),
            button.heightAnchor.constraint(equalToConstant: 64),
        ])

        // Refresh the tile once a real favicon arrives.
        SiteIcon.load(for: url) { [weak self] image in
            guard let self, self.quickURLs.indices.contains(tag), self.quickURLs[tag] == url else { return }
            icon.image = Self.composed(image: image, size: tileSize, cornerRadius: 9, fallbackFor: url)
        }
        return button
    }

    private static func composed(image: UIImage, size: CGFloat, cornerRadius: CGFloat,
                                 fallbackFor url: URL) -> UIImage {
        // Re-run through the same fit-composition path as tile(for:) using the
        // freshly fetched favicon instead of only the disk cache.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            let host = url.host ?? ""
            UIColor.secondarySystemBackground.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                         cornerRadius: cornerRadius).fill()
            let inset = size * 0.18
            let box = size - inset * 2
            var drawSize = image.size
            if drawSize.width > box || drawSize.height > box {
                let scale = min(box / drawSize.width, box / drawSize.height)
                drawSize = CGSize(width: drawSize.width * scale, height: drawSize.height * scale)
            }
            let origin = CGPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)
            context.cgContext.interpolationQuality = drawSize.width >= image.size.width ? .high : .none
            image.draw(in: CGRect(origin: origin, size: drawSize))
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
