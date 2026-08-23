import UIKit

protocol BrowserChromeViewDelegate: AnyObject {
    func browserChrome(_ chrome: BrowserChromeView, submitted text: String)
    func browserChromeDidRequestTabs(_ chrome: BrowserChromeView)
    func browserChrome(_ chrome: BrowserChromeView, requestedAdjacentTab offset: Int)
    func browserChrome(_ chrome: BrowserChromeView, textDidChange text: String)
    func browserChromeDidBeginEditing(_ chrome: BrowserChromeView)
    func browserChromeDidEndEditing(_ chrome: BrowserChromeView)
}

/// v24 "Quiet Deck": one floating command bar anchored below the status bar.
/// The top placement means the bar never interacts with the keyboard or the
/// home-indicator area, so no keyboard-ride constraints exist at all. All
/// commands live in a system-presented UIMenu (assigned by the owner), which
/// removes custom sheet presentations — and their presentation races — entirely.
final class BrowserChromeView: UIView, UITextFieldDelegate {
    private struct RenderState: Equatable {
        let address: String?
        let progress: Int
        let isLoading: Bool
        let tabCount: Int
        let isSecure: Bool
        let isPrivate: Bool
    }

    weak var delegate: BrowserChromeViewDelegate?
    let progressView = BrowserProgressView(progressViewStyle: .bar)
    private let material = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let toolsButton = PressableButton(symbol: "ellipsis", accessibilityLabel: "Page tools")
    private let tabsButton = PressableButton(symbol: "square.on.square", accessibilityLabel: "Tabs")
    private let tabCountLabel = UILabel()
    private let lockView = UIImageView(image: UIImage(systemName: "lock.fill"))
    private(set) var addressField = UITextField()
    private var renderedState: RenderState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: VulpraAppearance.Radius.bar).cgPath
    }

    /// The ⋯ menu is rebuilt by the owner whenever tab state changes, so the
    /// system always presents current navigation/page state.
    func updateToolsMenu(_ menu: UIMenu?) {
        toolsButton.menu = menu
        toolsButton.showsMenuAsPrimaryAction = true
    }

    func update(tab: BrowserTab, tabCount: Int) {
        let state = RenderState(
            address: tab.url?.absoluteString,
            progress: tab.progress,
            isLoading: tab.isLoading,
            tabCount: tabCount,
            isSecure: tab.url?.scheme?.lowercased() == "https",
            isPrivate: tab.isPrivate
        )
        guard state != renderedState else { return }

        let previous = renderedState
        renderedState = state
        if previous?.address != state.address, !addressField.isFirstResponder {
            addressField.text = Self.displayAddress(from: state.address)
        }
        let visibleCount = max(0, tabCount)
        tabCountLabel.text = visibleCount > 1 ? (visibleCount > 99 ? "99+" : "\(visibleCount)") : nil
        tabCountLabel.isHidden = visibleCount < 2
        tabsButton.accessibilityValue = "\(visibleCount) tabs"
        if previous?.isSecure != state.isSecure { lockView.isHidden = !state.isSecure }
        if previous?.progress != state.progress || previous?.isLoading != state.isLoading {
            progressView.update(progress: state.progress, loading: state.isLoading)
        }
        if previous?.isPrivate != state.isPrivate { applyPrivateTheme(state.isPrivate) }
    }

    static func displayAddress(from absolute: String?) -> String? {
        guard let absolute, let url = URL(string: absolute) else { return absolute }
        if let host = url.host { return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host }
        return absolute
    }

    func focusAddress() {
        addressField.becomeFirstResponder()
        addressField.selectAll(nil)
    }

    private func configure() {
        layer.shadowColor = UIColor(red: 0.35, green: 0.20, blue: 0.12, alpha: 1).cgColor
        layer.shadowOpacity = 0.13
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 8)
        material.layer.cornerCurve = .continuous
        material.layer.cornerRadius = VulpraAppearance.Radius.bar
        material.layer.borderWidth = 1 / UIScreen.main.scale
        material.layer.borderColor = VulpraAppearance.hairline.resolvedColor(with: traitCollection).cgColor
        material.clipsToBounds = true
        material.translatesAutoresizingMaskIntoConstraints = false
        addSubview(material)

        heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        progressView.tintColor = VulpraAppearance.accent
        progressView.trackTintColor = .clear
        progressView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressView)

        toolsButton.tintColor = .secondaryLabel
        toolsButton.contentMode = .center
        toolsButton.translatesAutoresizingMaskIntoConstraints = false
        material.contentView.addSubview(toolsButton)

        tabsButton.tintColor = .secondaryLabel
        tabsButton.translatesAutoresizingMaskIntoConstraints = false
        material.contentView.addSubview(tabsButton)
        tabCountLabel.font = .systemFont(ofSize: 10, weight: .bold)
        tabCountLabel.textColor = .white
        tabCountLabel.backgroundColor = VulpraAppearance.accent
        tabCountLabel.textAlignment = .center
        tabCountLabel.clipsToBounds = true
        tabCountLabel.layer.cornerRadius = 8
        tabCountLabel.translatesAutoresizingMaskIntoConstraints = false
        tabCountLabel.isUserInteractionEnabled = false
        tabsButton.addSubview(tabCountLabel)

        lockView.tintColor = .secondaryLabel
        lockView.contentMode = .scaleAspectFit
        lockView.translatesAutoresizingMaskIntoConstraints = false
        addressField.placeholder = L10n.tr("Search or enter website", "搜索或输入网址")
        addressField.font = .preferredFont(forTextStyle: .body)
        addressField.adjustsFontSizeToFitWidth = true
        addressField.autocapitalizationType = .none
        addressField.autocorrectionType = .no
        addressField.keyboardType = .webSearch
        addressField.returnKeyType = .go
        addressField.clearButtonMode = .whileEditing
        addressField.delegate = self
        addressField.addTarget(self, action: #selector(addressChanged), for: .editingChanged)
        addressField.translatesAutoresizingMaskIntoConstraints = false
        material.contentView.addSubview(lockView)
        material.contentView.addSubview(addressField)

        NSLayoutConstraint.activate([
            material.topAnchor.constraint(equalTo: topAnchor),
            material.leadingAnchor.constraint(equalTo: leadingAnchor),
            material.trailingAnchor.constraint(equalTo: trailingAnchor),
            material.bottomAnchor.constraint(equalTo: bottomAnchor),

            toolsButton.topAnchor.constraint(equalTo: material.contentView.topAnchor),
            toolsButton.bottomAnchor.constraint(equalTo: material.contentView.bottomAnchor),
            toolsButton.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor, constant: -4),

            tabsButton.topAnchor.constraint(equalTo: material.contentView.topAnchor),
            tabsButton.bottomAnchor.constraint(equalTo: material.contentView.bottomAnchor),
            tabsButton.trailingAnchor.constraint(equalTo: toolsButton.leadingAnchor),

            tabCountLabel.topAnchor.constraint(equalTo: tabsButton.topAnchor, constant: 9),
            tabCountLabel.trailingAnchor.constraint(equalTo: tabsButton.trailingAnchor, constant: 1),
            tabCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            tabCountLabel.heightAnchor.constraint(equalToConstant: 16),

            lockView.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor, constant: 18),
            lockView.centerYAnchor.constraint(equalTo: material.contentView.centerYAnchor),
            lockView.widthAnchor.constraint(equalToConstant: 13),

            addressField.leadingAnchor.constraint(equalTo: lockView.trailingAnchor, constant: 8),
            addressField.centerYAnchor.constraint(equalTo: material.contentView.centerYAnchor),
            addressField.topAnchor.constraint(greaterThanOrEqualTo: material.contentView.topAnchor, constant: 8),
            addressField.bottomAnchor.constraint(lessThanOrEqualTo: material.contentView.bottomAnchor, constant: -8),
            addressField.trailingAnchor.constraint(equalTo: tabsButton.leadingAnchor, constant: -2),

            progressView.topAnchor.constraint(equalTo: topAnchor),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
        ])

        tabsButton.addTarget(self, action: #selector(tabs), for: .touchUpInside)
        addGestureRecognizer(UISwipeGestureRecognizer(target: self, action: #selector(swipe(_:))).configured(.left))
        addGestureRecognizer(UISwipeGestureRecognizer(target: self, action: #selector(swipe(_:))).configured(.right))
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.browserChrome(self, submitted: textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        addressField.text = renderedState?.address
        delegate?.browserChromeDidBeginEditing(self)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        addressField.text = Self.displayAddress(from: renderedState?.address)
        delegate?.browserChromeDidEndEditing(self)
    }

    private func applyPrivateTheme(_ privateMode: Bool) {
        let effect = UIBlurEffect(style: privateMode ? .systemMaterialDark : .systemChromeMaterial)
        UIView.transition(with: material, duration: 0.25, options: [.transitionCrossDissolve]) {
            self.material.effect = effect
        }
        lockView.tintColor = privateMode ? UIColor(red: 0.18, green: 0.69, blue: 0.78, alpha: 1) : .secondaryLabel
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func addressChanged() { delegate?.browserChrome(self, textDidChange: addressField.text ?? "") }
    @objc private func tabs() { haptic(); delegate?.browserChromeDidRequestTabs(self) }
    @objc private func swipe(_ gesture: UISwipeGestureRecognizer) {
        delegate?.browserChrome(self, requestedAdjacentTab: gesture.direction == .left ? 1 : -1)
    }
}

private extension UISwipeGestureRecognizer {
    func configured(_ direction: UISwipeGestureRecognizer.Direction) -> Self { self.direction = direction; return self }
}
