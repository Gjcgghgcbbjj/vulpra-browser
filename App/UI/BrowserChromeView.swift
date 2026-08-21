import UIKit

protocol BrowserChromeViewDelegate: AnyObject {
    func browserChrome(_ chrome: BrowserChromeView, submitted text: String)
    func browserChromeDidRequestBack(_ chrome: BrowserChromeView)
    func browserChromeDidRequestForward(_ chrome: BrowserChromeView)
    func browserChromeDidRequestReloadOrStop(_ chrome: BrowserChromeView)
    func browserChromeDidRequestShare(_ chrome: BrowserChromeView)
    func browserChromeDidRequestTabs(_ chrome: BrowserChromeView)
    func browserChrome(_ chrome: BrowserChromeView, requestedAdjacentTab offset: Int)
    func browserChrome(_ chrome: BrowserChromeView, textDidChange text: String)
    func browserChromeDidBeginEditing(_ chrome: BrowserChromeView)
    func browserChromeDidEndEditing(_ chrome: BrowserChromeView)
}

final class BrowserChromeView: UIView, UITextFieldDelegate {
    private struct RenderState: Equatable {
        let address: String?
        let canGoBack: Bool
        let canGoForward: Bool
        let isLoading: Bool
        let progress: Int
        let tabCount: Int
        let isSecure: Bool
        let isPrivate: Bool
    }

    weak var delegate: BrowserChromeViewDelegate?
    let progressView = BrowserProgressView(progressViewStyle: .bar)
    private let material = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let backButton = PressableButton(symbol: "chevron.backward", accessibilityLabel: "Back")
    private let forwardButton = PressableButton(symbol: "chevron.forward", accessibilityLabel: "Forward")
    private let reloadButton = PressableButton(symbol: "arrow.clockwise", accessibilityLabel: "Reload")
    private let shareButton = PressableButton(symbol: "square.and.arrow.up", accessibilityLabel: "Share")
    private let tabsButton = PressableButton(symbol: "square.on.square", accessibilityLabel: "Tabs")
    private let addressBackground = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let lockView = UIImageView(image: UIImage(systemName: "lock.fill"))
    private(set) var addressField = UITextField()
    private var renderedState: RenderState?
    private var compactConstraint: NSLayoutConstraint!
    private var expandedConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 22).cgPath
    }

    func update(tab: BrowserTab, tabCount: Int) {
        let state = RenderState(
            address: tab.url?.absoluteString,
            canGoBack: tab.canGoBack,
            canGoForward: tab.canGoForward,
            isLoading: tab.isLoading,
            progress: tab.progress,
            tabCount: tabCount,
            isSecure: tab.url?.scheme?.lowercased() == "https",
            isPrivate: tab.isPrivate
        )
        guard state != renderedState else { return }

        let previous = renderedState
        renderedState = state
        if previous?.address != state.address, !addressField.isFirstResponder {
            // Show a clean domain while browsing; the full URL returns when
            // the field gains focus for editing or sharing.
            addressField.text = Self.displayAddress(from: state.address)
        }
        if previous?.canGoBack != state.canGoBack { backButton.isEnabled = state.canGoBack }
        if previous?.canGoForward != state.canGoForward { forwardButton.isEnabled = state.canGoForward }
        if previous?.isLoading != state.isLoading {
            reloadButton.setImage(
                UIImage(systemName: state.isLoading ? "xmark" : "arrow.clockwise"),
                for: .normal
            )
            reloadButton.accessibilityLabel = state.isLoading ? "Stop" : "Reload"
        }
        if previous?.tabCount != state.tabCount {
            tabsButton.accessibilityValue = "\(state.tabCount) tabs"
        }
        if previous?.isSecure != state.isSecure { lockView.isHidden = !state.isSecure }
        if previous?.progress != state.progress || previous?.isLoading != state.isLoading {
            progressView.update(progress: state.progress, loading: state.isLoading)
        }
        if previous?.isPrivate != state.isPrivate { applyPrivateTheme(state.isPrivate) }
    }

    /// Browsing chrome shows just the host ("example.com"); editing shows the
    /// full URL. Falls back to the raw string when no host exists.
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
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 5)
        material.layer.cornerRadius = 22
        material.clipsToBounds = true
        material.translatesAutoresizingMaskIntoConstraints = false
        addSubview(material)

        progressView.tintColor = VulpraAppearance.accent
        progressView.trackTintColor = .clear
        progressView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressView)

        addressBackground.layer.cornerRadius = 15
        addressBackground.clipsToBounds = true
        addressBackground.translatesAutoresizingMaskIntoConstraints = false
        material.contentView.addSubview(addressBackground)

        lockView.tintColor = .secondaryLabel
        lockView.contentMode = .scaleAspectFit
        lockView.translatesAutoresizingMaskIntoConstraints = false
        addressField.placeholder = L10n.tr("Search or enter website", "搜索或输入网址")
        addressField.autocapitalizationType = .none
        addressField.autocorrectionType = .no
        addressField.keyboardType = .webSearch
        addressField.returnKeyType = .go
        addressField.clearButtonMode = .whileEditing
        addressField.delegate = self
        addressField.addTarget(self, action: #selector(addressChanged), for: .editingChanged)
        addressField.translatesAutoresizingMaskIntoConstraints = false
        addressBackground.contentView.addSubview(lockView)
        addressBackground.contentView.addSubview(addressField)

        let buttons = UIStackView(arrangedSubviews: [backButton, forwardButton, reloadButton, shareButton, tabsButton])
        buttons.axis = .horizontal
        buttons.distribution = .equalSpacing
        buttons.translatesAutoresizingMaskIntoConstraints = false
        material.contentView.addSubview(buttons)

        compactConstraint = addressBackground.heightAnchor.constraint(equalToConstant: 38)
        expandedConstraint = addressBackground.heightAnchor.constraint(equalToConstant: 48)
        compactConstraint.isActive = true
        NSLayoutConstraint.activate([
            material.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            material.leadingAnchor.constraint(equalTo: leadingAnchor),
            material.trailingAnchor.constraint(equalTo: trailingAnchor),
            material.bottomAnchor.constraint(equalTo: bottomAnchor),
            addressBackground.topAnchor.constraint(equalTo: material.contentView.topAnchor, constant: 8),
            addressBackground.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor, constant: 10),
            addressBackground.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor, constant: -10),
            lockView.leadingAnchor.constraint(equalTo: addressBackground.contentView.leadingAnchor, constant: 12),
            lockView.centerYAnchor.constraint(equalTo: addressBackground.contentView.centerYAnchor),
            lockView.widthAnchor.constraint(equalToConstant: 13),
            addressField.leadingAnchor.constraint(equalTo: lockView.trailingAnchor, constant: 7),
            addressField.trailingAnchor.constraint(equalTo: addressBackground.contentView.trailingAnchor, constant: -8),
            addressField.topAnchor.constraint(equalTo: addressBackground.contentView.topAnchor),
            addressField.bottomAnchor.constraint(equalTo: addressBackground.contentView.bottomAnchor),
            buttons.topAnchor.constraint(equalTo: addressBackground.bottomAnchor, constant: 2),
            buttons.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor, constant: 10),
            buttons.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor, constant: -10),
            buttons.bottomAnchor.constraint(equalTo: material.contentView.bottomAnchor, constant: -4),
            progressView.topAnchor.constraint(equalTo: topAnchor),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])

        backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(forward), for: .touchUpInside)
        reloadButton.addTarget(self, action: #selector(reload), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(share), for: .touchUpInside)
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
        // Editing always shows the full URL so it can be corrected or shared.
        addressField.text = renderedState?.address
        delegate?.browserChromeDidBeginEditing(self)
        animateEditing(true)
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        addressField.text = Self.displayAddress(from: renderedState?.address)
        delegate?.browserChromeDidEndEditing(self)
        animateEditing(false)
    }

    /// Private-mode chrome: darker material and a violet accent so the mode is
    /// unmistakable at a glance, mirroring mainstream mobile browsers.
    private func applyPrivateTheme(_ privateMode: Bool) {
        let effect = UIBlurEffect(style: privateMode ? .systemMaterialDark : .systemChromeMaterial)
        UIView.transition(with: material, duration: 0.25, options: [.transitionCrossDissolve]) {
            self.material.effect = effect
        }
        lockView.tintColor = privateMode ? UIColor(red: 0.78, green: 0.64, blue: 1.0, alpha: 1) : .secondaryLabel
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func animateEditing(_ editing: Bool) {
        compactConstraint.isActive = !editing
        expandedConstraint.isActive = editing
        let changes = { self.transform = editing ? CGAffineTransform(translationX: 0, y: -6) : .identity; self.layoutIfNeeded() }
        if UIAccessibility.isReduceMotionEnabled { changes() }
        else { UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.25, options: [.beginFromCurrentState], animations: changes) }
    }

    @objc private func addressChanged() { delegate?.browserChrome(self, textDidChange: addressField.text ?? "") }
    @objc private func back() { haptic(); delegate?.browserChromeDidRequestBack(self) }
    @objc private func forward() { haptic(); delegate?.browserChromeDidRequestForward(self) }
    @objc private func reload() { haptic(); delegate?.browserChromeDidRequestReloadOrStop(self) }
    @objc private func share() { haptic(); delegate?.browserChromeDidRequestShare(self) }
    @objc private func tabs() { haptic(); delegate?.browserChromeDidRequestTabs(self) }
    @objc private func swipe(_ gesture: UISwipeGestureRecognizer) {
        delegate?.browserChrome(self, requestedAdjacentTab: gesture.direction == .left ? 1 : -1)
    }
}

private extension UISwipeGestureRecognizer {
    func configured(_ direction: UISwipeGestureRecognizer.Direction) -> Self { self.direction = direction; return self }
}
