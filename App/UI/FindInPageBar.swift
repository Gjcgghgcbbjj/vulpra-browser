import UIKit

/// A quiet floating find bar that docks under the command chrome. Owns no
/// search logic — it forwards to the caller and renders match counts.
final class FindInPageBar: UIView, UITextFieldDelegate {
    var onTextChange: ((String) -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onClose: (() -> Void)?

    private let material = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let field = UITextField()
    private let countLabel = UILabel()
    private let previousButton = PressableButton(symbol: "chevron.up", accessibilityLabel: "Previous match")
    private let nextButton = PressableButton(symbol: "chevron.down", accessibilityLabel: "Next match")
    private let closeButton = PressableButton(symbol: "xmark", accessibilityLabel: "Close find bar")

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)
        material.layer.cornerCurve = .continuous
        material.layer.cornerRadius = 19
        material.clipsToBounds = true
        material.translatesAutoresizingMaskIntoConstraints = false
        addSubview(material)

        field.placeholder = L10n.tr("Find in page", "页面内查找")
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .search
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false
        field.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        material.contentView.addSubview(field)

        countLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        countLabel.textColor = .secondaryLabel
        countLabel.contentCompressionResistancePriority = .required
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        material.contentView.addSubview(countLabel)

        [previousButton, nextButton, closeButton].forEach {
            $0.tintColor = .secondaryLabel
            $0.translatesAutoresizingMaskIntoConstraints = false
            material.contentView.addSubview($0)
        }
        previousButton.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            material.topAnchor.constraint(equalTo: topAnchor),
            material.leadingAnchor.constraint(equalTo: leadingAnchor),
            material.trailingAnchor.constraint(equalTo: trailingAnchor),
            material.bottomAnchor.constraint(equalTo: bottomAnchor),

            field.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor, constant: 16),
            field.centerYAnchor.constraint(equalTo: material.contentView.centerYAnchor),
            field.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -8),

            countLabel.centerYAnchor.constraint(equalTo: material.contentView.centerYAnchor),
            countLabel.trailingAnchor.constraint(equalTo: previousButton.leadingAnchor, constant: -6),

            previousButton.centerYAnchor.constraint(equalTo: material.contentView.centerYAnchor),
            nextButton.centerYAnchor.constraint(equalTo: material.contentView.centerYAnchor),
            closeButton.centerYAnchor.constraint(equalTo: material.contentView.centerYAnchor),
            previousButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -2),
            nextButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -2),
            closeButton.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor, constant: -6),

            material.heightAnchor.constraint(greaterThanOrEqualToConstant: 46),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 46)
    }

    func focus() {
        field.becomeFirstResponder()
    }

    var textForSearch: String? { field.text }

    func update(count: Int, current: Int) {
        countLabel.text = count > 0 ? "\(current)/\(count)" : (field.text?.isEmpty == false ? "0" : nil)
        let dimmed = count == 0
        previousButton.isEnabled = count > 0
        nextButton.isEnabled = count > 0
        UIView.performWithoutAnimation {
            previousButton.alpha = dimmed ? 0.4 : 1
            nextButton.alpha = dimmed ? 0.4 : 1
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onNext?()
        return true
    }

    @objc private func textChanged() { onTextChange?(field.text ?? "") }
    @objc private func previousTapped() { onPrevious?() }
    @objc private func nextTapped() { onNext?() }
    @objc private func closeTapped() { onClose?() }
}
