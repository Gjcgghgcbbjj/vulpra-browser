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
}

final class BrowserChromeView: UIView, UITextFieldDelegate {
    weak var delegate: BrowserChromeViewDelegate?
    let progressView = BrowserProgressView(progressViewStyle: .bar)
    private let material = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let backButton = PressableButton(symbol: "chevron.backward", accessibilityLabel: VulpraL10n.text("browser.back"))
    private let forwardButton = PressableButton(symbol: "chevron.forward", accessibilityLabel: VulpraL10n.text("browser.forward"))
    private let reloadButton = PressableButton(symbol: "arrow.clockwise", accessibilityLabel: VulpraL10n.text("browser.reload"))
    private let shareButton = PressableButton(symbol: "square.and.arrow.up", accessibilityLabel: VulpraL10n.text("browser.share"))
    private let tabsButton = PressableButton(symbol: "square.on.square", accessibilityLabel: VulpraL10n.text("browser.tabs"))
    private let tabCountLabel = UILabel()
    private let addressBackground = UIView()
    private let lockView = UIImageView(image: UIImage(systemName: "lock.fill"))
    private let buttonRow = UIStackView()
    private(set) var addressField = UITextField()
    private var isLoading = false
    private var compactConstraint: NSLayoutConstraint!
    private var focusedConstraint: NSLayoutConstraint!
    private var buttonRowConstraint: NSLayoutConstraint!
    private var collapsedRowConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: VulpraAppearance.dockRadius).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    func update(tab: BrowserTab, tabCount: Int) {
        if !addressField.isFirstResponder { addressField.text = tab.url?.absoluteString }
        backButton.isEnabled = tab.canGoBack
        forwardButton.isEnabled = tab.canGoForward
        isLoading = tab.isLoading
        reloadButton.setImage(UIImage(systemName: tab.isLoading ? "xmark" : "arrow.clockwise"), for: .normal)
        reloadButton.accessibilityLabel = VulpraL10n.text(tab.isLoading ? "browser.stop" : "browser.reload")
        tabsButton.accessibilityValue = VulpraL10n.format("browser.tabs.count", tabCount)
        tabCountLabel.text = tabCount > 99 ? "99+" : String(tabCount)
        let symbol = tab.url == nil ? "magnifyingglass" :
            tab.url?.scheme?.lowercased() == "https" ? "lock.fill" : "globe"
        lockView.image = UIImage(systemName: symbol)
        progressView.update(progress: tab.progress, loading: tab.isLoading)
    }

    func focusAddress() {
        addressField.becomeFirstResponder()
        addressField.selectAll(nil)
    }

    private func configure() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.07
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 3)
        material.layer.cornerRadius = VulpraAppearance.dockRadius
        material.layer.cornerCurve = .continuous
        material.layer.borderWidth = 1 / UIScreen.main.scale
        material.clipsToBounds = true
        material.translatesAutoresizingMaskIntoConstraints = false
        addSubview(material)

        progressView.tintColor = VulpraAppearance.accent
        progressView.trackTintColor = .clear
        progressView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressView)

        addressBackground.layer.cornerRadius = VulpraAppearance.itemRadius
        addressBackground.layer.cornerCurve = .continuous
        addressBackground.clipsToBounds = true
        addressBackground.translatesAutoresizingMaskIntoConstraints = false
        material.contentView.addSubview(addressBackground)

        lockView.tintColor = .secondaryLabel
        lockView.contentMode = .scaleAspectFit
        lockView.translatesAutoresizingMaskIntoConstraints = false
        addressField.placeholder = VulpraL10n.text("browser.search.placeholder")
        addressField.autocapitalizationType = .none
        addressField.autocorrectionType = .no
        addressField.keyboardType = .webSearch
        addressField.returnKeyType = .go
        addressField.clearButtonMode = .whileEditing
        addressField.delegate = self
        addressField.addTarget(self, action: #selector(addressChanged), for: .editingChanged)
        addressField.translatesAutoresizingMaskIntoConstraints = false
        addressBackground.addSubview(lockView)
        addressBackground.addSubview(addressField)

        [backButton, forwardButton, reloadButton, shareButton, tabsButton].forEach(buttonRow.addArrangedSubview)
        buttonRow.axis = .horizontal
        buttonRow.alignment = .center
        buttonRow.distribution = .equalSpacing
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.clipsToBounds = true
        material.contentView.addSubview(buttonRow)

        tabCountLabel.font = .systemFont(ofSize: 9, weight: .bold)
        tabCountLabel.textColor = .white
        tabCountLabel.textAlignment = .center
        tabCountLabel.backgroundColor = VulpraAppearance.accent
        tabCountLabel.layer.cornerRadius = 8
        tabCountLabel.clipsToBounds = true
        tabCountLabel.translatesAutoresizingMaskIntoConstraints = false
        tabsButton.addSubview(tabCountLabel)

        compactConstraint = addressBackground.heightAnchor.constraint(equalToConstant: 42)
        focusedConstraint = addressBackground.heightAnchor.constraint(equalToConstant: 48)
        buttonRowConstraint = buttonRow.heightAnchor.constraint(equalToConstant: 44)
        collapsedRowConstraint = buttonRow.heightAnchor.constraint(equalToConstant: 0)
        compactConstraint.isActive = true
        buttonRowConstraint.isActive = true
        NSLayoutConstraint.activate([
            material.topAnchor.constraint(equalTo: topAnchor),
            material.leadingAnchor.constraint(equalTo: leadingAnchor),
            material.trailingAnchor.constraint(equalTo: trailingAnchor),
            material.bottomAnchor.constraint(equalTo: bottomAnchor),
            addressBackground.topAnchor.constraint(equalTo: material.contentView.topAnchor, constant: 8),
            addressBackground.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor, constant: 8),
            addressBackground.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor, constant: -8),
            lockView.leadingAnchor.constraint(equalTo: addressBackground.leadingAnchor, constant: 12),
            lockView.centerYAnchor.constraint(equalTo: addressBackground.centerYAnchor),
            lockView.widthAnchor.constraint(equalToConstant: 13),
            addressField.leadingAnchor.constraint(equalTo: lockView.trailingAnchor, constant: 7),
            addressField.trailingAnchor.constraint(equalTo: addressBackground.trailingAnchor, constant: -10),
            addressField.topAnchor.constraint(equalTo: addressBackground.topAnchor),
            addressField.bottomAnchor.constraint(equalTo: addressBackground.bottomAnchor),
            buttonRow.topAnchor.constraint(equalTo: addressBackground.bottomAnchor, constant: 2),
            buttonRow.leadingAnchor.constraint(equalTo: material.contentView.leadingAnchor, constant: 8),
            buttonRow.trailingAnchor.constraint(equalTo: material.contentView.trailingAnchor, constant: -8),
            buttonRow.bottomAnchor.constraint(equalTo: material.contentView.bottomAnchor, constant: -4),
            progressView.topAnchor.constraint(equalTo: topAnchor),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            tabCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            tabCountLabel.heightAnchor.constraint(equalToConstant: 16),
            tabCountLabel.topAnchor.constraint(equalTo: tabsButton.topAnchor, constant: 2),
            tabCountLabel.trailingAnchor.constraint(equalTo: tabsButton.trailingAnchor, constant: 1),
        ])
        applyColors()

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

    func textFieldDidBeginEditing(_ textField: UITextField) { animateEditing(true) }
    func textFieldDidEndEditing(_ textField: UITextField) { animateEditing(false) }

    private func animateEditing(_ editing: Bool) {
        compactConstraint.isActive = !editing
        focusedConstraint.isActive = editing
        buttonRowConstraint.isActive = !editing
        collapsedRowConstraint.isActive = editing
        let changes = {
            self.buttonRow.alpha = editing ? 0 : 1
            self.superview?.layoutIfNeeded()
        }
        if UIAccessibility.isReduceMotionEnabled { changes() }
        else { UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: changes) }
    }

    private func applyColors() {
        material.layer.borderColor = VulpraAppearance.separator.cgColor
        addressBackground.backgroundColor = UIColor.tertiarySystemFill
        lockView.tintColor = .secondaryLabel
        addressField.textColor = VulpraAppearance.graphite
    }

    @objc private func addressChanged() { delegate?.browserChrome(self, textDidChange: addressField.text ?? "") }
    @objc private func back() { delegate?.browserChromeDidRequestBack(self) }
    @objc private func forward() { delegate?.browserChromeDidRequestForward(self) }
    @objc private func reload() { delegate?.browserChromeDidRequestReloadOrStop(self) }
    @objc private func share() { delegate?.browserChromeDidRequestShare(self) }
    @objc private func tabs() { delegate?.browserChromeDidRequestTabs(self) }
    @objc private func swipe(_ gesture: UISwipeGestureRecognizer) {
        delegate?.browserChrome(self, requestedAdjacentTab: gesture.direction == .left ? 1 : -1)
    }
}

private extension UISwipeGestureRecognizer {
    func configured(_ direction: UISwipeGestureRecognizer.Direction) -> Self { self.direction = direction; return self }
}
