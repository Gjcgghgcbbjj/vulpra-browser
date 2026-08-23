import UIKit

final class TabCardCell: UICollectionViewCell {
    static let reuseIdentifier = "TabCardCell"

    let closeButton = PressableButton(symbol: "xmark.circle.fill", accessibilityLabel: "Close tab")
    private let preview = UIImageView()
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()
    private let metadataBar = UIView()
    private let hairline = UIView()
    private var representedURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        if contentView.layer.borderWidth <= 1 { contentView.layer.borderColor = VulpraAppearance.hairline.resolvedColor(with: traitCollection).cgColor }
        hairline.backgroundColor = VulpraAppearance.hairline.resolvedColor(with: traitCollection)
    }

    func update(tab: BrowserTab, selected: Bool) {
        titleLabel.text = tab.title.isEmpty ? L10n.tr("New tab", "新标签页") : tab.title
        let hostText = tab.url.flatMap { BrowserChromeView.displayAddress(from: $0.absoluteString) }
            ?? (tab.isPrivate ? L10n.tr("Private tab", "隐私标签页") : L10n.tr("New tab", "新标签页"))
        urlLabel.text = hostText
        accessibilityLabel = "\(titleLabel.text ?? ""), \(hostText)"

        contentView.layer.borderColor = selected
            ? VulpraAppearance.accent.cgColor
            : VulpraAppearance.hairline.resolvedColor(with: traitCollection).cgColor
        contentView.layer.borderWidth = selected ? 2 : 1 / UIScreen.main.scale

        representedURL = tab.url
        if let thumbnail = tab.thumbnail {
            preview.image = thumbnail
            preview.contentMode = .scaleAspectFill
            preview.backgroundColor = .tertiarySystemBackground
        } else if tab.isPrivate {
            preview.image = UIImage(systemName: "eyeglasses")
            preview.tintColor = .secondaryLabel
            preview.backgroundColor = .tertiarySystemBackground
            preview.contentMode = .center
        } else {
            preview.image = SiteIcon.placeholder(for: tab.url, size: 68)
            preview.backgroundColor = .clear
            preview.contentMode = .center
        }
    }

    private func configure() {
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerCurve = .continuous
        contentView.layer.cornerRadius = 22
        contentView.layer.borderWidth = 1 / UIScreen.main.scale
        contentView.layer.borderColor = VulpraAppearance.hairline.cgColor
        contentView.clipsToBounds = true

        preview.backgroundColor = .tertiarySystemBackground
        preview.image = UIImage(systemName: "globe")
        preview.tintColor = .secondaryLabel
        preview.contentMode = .center
        preview.translatesAutoresizingMaskIntoConstraints = false

        metadataBar.backgroundColor = .tertiarySystemBackground
        metadataBar.translatesAutoresizingMaskIntoConstraints = false
        hairline.backgroundColor = VulpraAppearance.hairline
        hairline.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1
        urlLabel.font = .preferredFont(forTextStyle: .caption1)
        urlLabel.textColor = .secondaryLabel
        urlLabel.numberOfLines = 1
        let labels = UIStackView(arrangedSubviews: [titleLabel, urlLabel])
        labels.axis = .vertical
        labels.spacing = 2
        labels.translatesAutoresizingMaskIntoConstraints = false

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = .secondaryLabel
        contentView.addSubview(preview)
        contentView.addSubview(metadataBar)
        metadataBar.addSubview(hairline)
        metadataBar.addSubview(labels)
        metadataBar.addSubview(closeButton)

        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: contentView.topAnchor),
            preview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            metadataBar.topAnchor.constraint(equalTo: preview.bottomAnchor),
            metadataBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            metadataBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            metadataBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            metadataBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            hairline.topAnchor.constraint(equalTo: metadataBar.topAnchor),
            hairline.leadingAnchor.constraint(equalTo: metadataBar.leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: metadataBar.trailingAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            labels.centerYAnchor.constraint(equalTo: metadataBar.centerYAnchor),
            labels.leadingAnchor.constraint(equalTo: metadataBar.leadingAnchor, constant: 14),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -4),

            closeButton.topAnchor.constraint(greaterThanOrEqualTo: metadataBar.topAnchor, constant: 6),
            closeButton.centerYAnchor.constraint(equalTo: metadataBar.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: metadataBar.trailingAnchor, constant: -5),
        ])
    }
}
