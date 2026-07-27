import UIKit

final class VulpraEmptyStateView: UIView {
    private var action: (() -> Void)?
    private var secondaryAction: (() -> Void)?

    init(symbol: String, title: String, subtitle: String? = nil,
         actionTitle: String? = nil, action: (() -> Void)? = nil,
         secondaryActionTitle: String? = nil, secondaryAction: (() -> Void)? = nil) {
        super.init(frame: .zero)
        self.action = action
        self.secondaryAction = secondaryAction
        let imageView = UIImageView(image: UIImage(systemName: symbol))
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
        imageView.tintColor = .tertiaryLabel

        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0

        var arrangedSubviews: [UIView] = [imageView, label]
        if let subtitle {
            let detail = UILabel()
            detail.text = subtitle
            detail.font = .preferredFont(forTextStyle: .caption1)
            detail.textColor = .tertiaryLabel
            detail.textAlignment = .center
            detail.numberOfLines = 2
            arrangedSubviews.append(detail)
        }
        if let actionTitle, action != nil {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.title = actionTitle
            configuration.image = UIImage(systemName: "arrow.clockwise")
            configuration.imagePadding = 7
            button.configuration = configuration
            button.addTarget(self, action: #selector(performAction), for: .touchUpInside)
            arrangedSubviews.append(button)
        }
        if let secondaryActionTitle, secondaryAction != nil {
            let button = UIButton(type: .system)
            var configuration = UIButton.Configuration.plain()
            configuration.title = secondaryActionTitle
            configuration.image = UIImage(systemName: "lock.open")
            configuration.imagePadding = 7
            button.configuration = configuration
            button.addTarget(self, action: #selector(performSecondaryAction), for: .touchUpInside)
            arrangedSubviews.append(button)
        }
        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 38),
            imageView.heightAnchor.constraint(equalToConstant: 38),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -24),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
        ])
        if action == nil {
            isAccessibilityElement = true
            accessibilityLabel = title
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    @objc private func performAction() {
        action?()
    }

    @objc private func performSecondaryAction() { secondaryAction?() }
}
