import UIKit

final class TabCardCell: UICollectionViewCell {
    static let reuseIdentifier = "TabCardCell"
    let closeButton = PressableButton(
        symbol: "xmark.circle.fill", accessibilityLabel: VulpraL10n.text("tab.close")
    )
    private let preview = UIImageView()
    private let titleLabel = UILabel()
    private let urlLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = VulpraAppearance.itemRadius
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = VulpraAppearance.separator.cgColor
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

    func update(tab: BrowserTab, selected: Bool) {
        titleLabel.text = tab.displayTitle
        urlLabel.text = tab.url?.host ?? VulpraL10n.text(tab.isPrivate ? "tab.private" : "tab.new")
        contentView.layer.borderWidth = selected ? 2 : 1
        let borderColor = tab.isPrivate ? VulpraAppearance.privateAccent : VulpraAppearance.accent
        contentView.layer.borderColor = (selected ? borderColor : VulpraAppearance.separator).cgColor
        preview.image = tab.thumbnail ?? UIImage(systemName: tab.isPrivate ? "hand.raised.fill" : "globe")
        preview.contentMode = tab.thumbnail == nil ? .center : .scaleAspectFill
        accessibilityLabel = "\(tab.displayTitle), \(urlLabel.text ?? "")"
    }
}
