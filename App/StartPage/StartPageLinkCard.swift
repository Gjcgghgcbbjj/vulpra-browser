import UIKit

enum StartPageCardStyle {
    case pinned
    case recent
}

/// A home card with real surface quality: opaque elevated fill, warm ambient
/// shadow, press-down micro-interaction, and haptic confirmation.
final class StartPageLinkCard: UIView {
    let siteURL: URL
    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let hostLabel = UILabel()
    private var representedURL: URL?
    private var onOpen: ((URL) -> Void)?
    private var representedAccessibilityLabel: String = ""

    init(title: String, url: URL, style: StartPageCardStyle, onOpen: @escaping (URL) -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.onOpen = onOpen
        self.siteURL = url
        representedAccessibilityLabel = title

        let imageSize: CGFloat = style == .pinned ? 46 : 36
        backgroundColor = VulpraAppearance.surfaceElevated
        VulpraAppearance.elevate(self, radius: style == .pinned ? VulpraAppearance.Radius.card : 17)

        icon.image = SiteIcon.tile(for: url, size: imageSize, cornerRadius: imageSize * 0.31)
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false

        let host = url.host ?? ""
        titleLabel.text = title
        titleLabel.font = style == .pinned ? {
            let base = UIFont.systemFont(ofSize: 16, weight: .semibold)
            if let descriptor = base.fontDescriptor.withDesign(.rounded) {
                return UIFontMetrics(forTextStyle: .body).scaledFont(
                    for: UIFont(descriptor: descriptor, size: base.pointSize))
            }
            return UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
        }() : .preferredFont(forTextStyle: .subheadline)
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

        addSubview(icon)
        addSubview(labels)
        let verticalPadding: CGFloat = style == .pinned ? 15 : 11
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: style == .pinned ? 76 : 58),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            icon.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: verticalPadding),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: imageSize),
            icon.heightAnchor.constraint(equalToConstant: imageSize),

            labels.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
        ])

        // Quick tap opens; a long-press is reserved for the context menu
        // interaction the owner attaches (pin management). The scale feedback
        // rides on raw touches so it works alongside both.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = title
        loadFavicon(for: url, size: imageSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override var accessibilityLabel: String? {
        get { representedAccessibilityLabel }
        set { representedAccessibilityLabel = newValue ?? "" }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.borderColor = VulpraAppearance.hairline.resolvedColor(with: traitCollection).cgColor
    }

    private func setPressed(_ pressed: Bool) {
        VulpraMotion.spring(damping: 0.6, duration: 0.3) {
            self.transform = pressed ? CGAffineTransform(scaleX: 0.965, y: 0.965) : .identity
            self.layer.shadowOpacity = pressed ? 0.04 : 0.07
        }
        if pressed { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let onOpen else { return }
        onOpen(siteURL)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        setPressed(true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        setPressed(false)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        setPressed(false)
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
