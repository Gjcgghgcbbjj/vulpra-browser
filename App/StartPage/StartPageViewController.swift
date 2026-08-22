import UIKit

protocol StartPageViewControllerDelegate: AnyObject {
    func startPage(_ controller: StartPageViewController, open text: String)
}

/// Chrome-style new tab page: colorful wordmark, a full-width search
/// capsule, and up to eight circular shortcuts to bookmarked sites.
/// Navigation (bookmarks/history/downloads/settings/private tab) lives in
/// the toolbar's page-tools menu, mirroring Chrome — the home screen stays
/// purely about search and shortcuts.
final class StartPageViewController: UIViewController, UITextFieldDelegate {
    weak var delegate: StartPageViewControllerDelegate?

    private let gridStack = UIStackView()
    private let sectionHeader = UILabel()
    private let emptyHint = UILabel()
    private var quickURLs: [URL] = []
    private let columns = 4
    private let tileSize: CGFloat = 56

    // MARK: - Brand mark

    /// Google-logo-style multicolor wordmark — instantly reads as "search
    /// home" without copying any asset.
    private lazy var logoLabel: UILabel = {
        let palette: [UIColor] = [#colorLiteral(red: 0.26, green: 0.52, blue: 0.96, alpha: 1),   // blue
                                  #colorLiteral(red: 0.92, green: 0.26, blue: 0.21, alpha: 1),   // red
                                  #colorLiteral(red: 0.98, green: 0.74, blue: 0.02, alpha: 1),   // yellow
                                  #colorLiteral(red: 0.26, green: 0.52, blue: 0.96, alpha: 1),   // blue
                                  #colorLiteral(red: 0.20, green: 0.66, blue: 0.32, alpha: 1),   // green
                                  #colorLiteral(red: 0.92, green: 0.26, blue: 0.21, alpha: 1)]   // red
        let text = NSMutableAttributedString(string: "Vulpra")
        for (index, letter) in text.string.enumerated() {
            let range = NSRange(location: index, length: 1)
            text.addAttribute(.foregroundColor,
                              value: palette[index % palette.count],
                              range: range)
            if letter == "l" {
                text.addAttribute(.font, value: UIFont.systemFont(ofSize: 40, weight: .semibold), range: range)
            }
        }
        let label = UILabel()
        label.attributedText = text
        label.font = UIFont.systemFont(ofSize: 40, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    private let searchField: UITextField = {
        let field = UITextField()
        field.placeholder = L10n.tr("Search or enter website", "搜索或输入网址")
        field.backgroundColor = .secondarySystemFill
        field.layer.cornerRadius = 24
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .go
        field.keyboardType = .webSearch
        field.autocapitalizationType = .none
        field.autocorrectionType = .no

        let magnifier = UIImageView(image: UIImage(systemName: "magnifyingglass",
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)))
        magnifier.tintColor = .secondaryLabel
        magnifier.contentMode = .center
        magnifier.frame = CGRect(x: 0, y: 0, width: 36, height: 24)
        field.leftView = magnifier
        field.leftViewMode = .always

        let rightPad = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        field.rightView = rightPad
        field.rightViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return field
    }()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadQuickSites()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        sectionHeader.text = L10n.tr("Shortcuts", "快捷方式")
        sectionHeader.font = .systemFont(ofSize: 14, weight: .semibold)
        sectionHeader.textColor = .secondaryLabel

        emptyHint.text = L10n.tr("Bookmark sites and your shortcuts will appear here.",
                                 "收藏网站后，快捷方式会显示在这里。")
        emptyHint.font = .systemFont(ofSize: 13)
        emptyHint.textColor = .tertiaryLabel
        emptyHint.textAlignment = .center
        emptyHint.numberOfLines = 0

        gridStack.axis = .vertical
        gridStack.spacing = 20

        let stack = UIStackView(arrangedSubviews: [logoLabel, searchField, sectionHeader, gridStack, emptyHint])
        stack.axis = .vertical
        stack.spacing = 28
        stack.setCustomSpacing(26, after: logoLabel)
        stack.setCustomSpacing(34, after: searchField)
        stack.setCustomSpacing(16, after: sectionHeader)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -64),
            searchField.leadingAnchor.constraint(greaterThanOrEqualTo: stack.leadingAnchor),
            searchField.trailingAnchor.constraint(lessThanOrEqualTo: stack.trailingAnchor),
        ])
        searchField.delegate = self
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.startPage(self, open: textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }

    // MARK: - Shortcuts grid

    /// Favorites only — history never clutters the home screen.
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
        let hasSites = !unique.isEmpty
        gridStack.isHidden = !hasSites
        sectionHeader.isHidden = !hasSites
        emptyHint.isHidden = hasSites
        guard hasSites else { return }

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

    /// Circular tile in the Chrome idiom: disc background, centered favicon,
    /// single-line label underneath.
    private func makeTile(title: String, url: URL, tag: Int) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 7

        let icon = UIImageView(image: SiteIcon.tile(for: url, size: tileSize, cornerRadius: tileSize / 2))
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: tileSize),
            icon.heightAnchor.constraint(equalToConstant: tileSize),
        ])

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
            button.heightAnchor.constraint(equalToConstant: 80),
        ])

        // Refresh the tile once a real favicon arrives.
        SiteIcon.load(for: url) { [weak self] image in
            guard let self, self.quickURLs.indices.contains(tag), self.quickURLs[tag] == url else { return }
            icon.image = Self.composed(image: image, size: tileSize, cornerRadius: tileSize / 2, fallbackFor: url)
        }
        return button
    }

    private static func composed(image: UIImage, size: CGFloat, cornerRadius: CGFloat,
                                 fallbackFor url: URL) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            let cgContext = context.cgContext
            cgContext.interpolationQuality =
                drawSize.width >= image.size.width ? .high : .none
            UIColor.secondarySystemBackground.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                         cornerRadius: cornerRadius).fill()
            let inset = size * 0.22
            let box = size - inset * 2
            var drawSize = image.size
            if drawSize.width > box || drawSize.height > box {
                let scale = min(box / drawSize.width, box / drawSize.height)
                drawSize = CGSize(width: drawSize.width * scale, height: drawSize.height * scale)
            }
            let origin = CGPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    @objc private func openQuickSite(_ sender: UIButton) {
        guard quickURLs.indices.contains(sender.tag) else { return }
        delegate?.startPage(self, open: quickURLs[sender.tag].absoluteString)
    }
}
