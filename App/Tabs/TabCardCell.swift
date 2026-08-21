import UIKit

final class TabCardCell: UICollectionViewCell {
    static let reuseIdentifier = "TabCardCell"
    let closeButton = PressableButton(symbol: "xmark.circle.fill", accessibilityLabel: "Close tab")
    private let preview = UIImageView()
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 18
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true
        preview.backgroundColor = .tertiarySystemBackground
        preview.image = UIImage(systemName: "globe")
        preview.tintColor = .tertiaryLabel
        preview.contentMode = .center
        preview.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 1
        urlLabel.font = .preferredFont(forTextStyle: .caption1)
        urlLabel.textColor = .secondaryLabel
        urlLabel.numberOfLines = 1
        let labels = UIStackView(arrangedSubviews: [titleLabel, urlLabel])
        labels.axis = .vertical
        labels.spacing = 2
        labels.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(preview)
        contentView.addSubview(labels)
        contentView.addSubview(closeButton)
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: contentView.topAnchor),
            preview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -58),
            labels.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            labels.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            labels.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -9),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private var representedURL: URL?

    func update(tab: BrowserTab, selected: Bool) {
        titleLabel.text = tab.title
        let hostText = tab.url.flatMap { BrowserChromeView.displayAddress(from: $0.absoluteString) }
            ?? (tab.isPrivate ? L10n.tr("Private tab", "隐私标签页") : L10n.tr("New tab", "新标签页"))
        urlLabel.text = hostText
        contentView.layer.borderWidth = selected ? 2 : 0
        contentView.layer.borderColor = VulpraAppearance.accent.cgColor

        representedURL = tab.url
        if let thumbnail = tab.thumbnail {
            preview.image = thumbnail
            preview.contentMode = .scaleAspectFill
        } else if let url = tab.url, !tab.isPrivate {
            // Letter avatar immediately; real favicon when cached/fetched.
            preview.image = SiteIcon.placeholder(for: url)
            preview.backgroundColor = .clear
            preview.contentMode = .scaleAspectFill
            SiteIcon.load(for: url) { [weak self] image in
                guard let self, self.representedURL == url else { return }
                self.preview.image = image
                self.preview.setNeedsLayout()
            }
        } else {
            preview.image = UIImage(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
            preview.tintColor = .secondaryLabel
            preview.backgroundColor = .tertiarySystemBackground
            preview.contentMode = .center
        }
        accessibilityLabel = "\(tab.title), \(hostText)"
    }
}
