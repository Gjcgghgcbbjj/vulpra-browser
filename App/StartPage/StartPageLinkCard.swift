import UIKit

enum StartPageCardStyle {
    case pinned
    case recent
}

final class StartPageLinkCard: UIView {
    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let hostLabel = UILabel()
    private var representedURL: URL?

    init(title: String, url: URL, style: StartPageCardStyle, onOpen: @escaping (URL) -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let imageSize: CGFloat = style == .pinned ? 44 : 34
        let surfaceFill = VulpraAppearance.cardFill
        backgroundColor = surfaceFill
        VulpraAppearance.elevate(self, radius: style == .pinned ? 20 : 17, opacity: 0.06)

        icon.image = SiteIcon.tile(for: url, size: imageSize, cornerRadius: imageSize * 0.31)
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false

        let host = url.host ?? ""
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: style == .pinned ? .body : .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.lineBreakMode = .byTruncatingTail
        hostLabel.text = host.replacingOccurrences(of: "www.", with: "")
        hostLabel.font = .preferredFont(forTextStyle: .caption1)
        hostLabel.adjustsFontForContentSizeCategory = true
        hostLabel.textColor = .secondaryLabel
        hostLabel.lineBreakMode = .byTruncatingMiddle

        let labels = UIStackView(arrangedSubviews: [titleLabel, hostLabel])
        labels.axis = .vertical
        labels.spacing = 2
        labels.alignment = .leading
        labels.translatesAutoresizingMaskIntoConstraints = false

        let button = UIButton(type: .custom)
        button.accessibilityLabel = title
        button.addAction(UIAction { [weak self] _ in onOpen(url) }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        addSubview(icon)
        addSubview(labels)
        addSubview(button)
        let verticalPadding: CGFloat = style == .pinned ? 15 : 11
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: style == .pinned ? 74 : 58),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            icon.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: verticalPadding),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: imageSize),
            icon.heightAnchor.constraint(equalToConstant: imageSize),

            labels.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),

            button.topAnchor.constraint(equalTo: topAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        loadFavicon(for: url, size: imageSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.borderColor = VulpraAppearance.hairline.resolvedColor(with: traitCollection).cgColor
    }

    private func loadFavicon(for url: URL, size: CGFloat) {
        representedURL = url
        SiteIcon.load(for: url) { [weak self] image in
            guard let self, self.representedURL == url else { return }
            self.icon.image = SiteIcon.tile(
                for: url,
                size: size,
                cornerRadius: size * 0.31,
                favicon: image
            )
        }
    }
}
