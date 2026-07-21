import UIKit

protocol BrowserChromeViewDelegate: AnyObject {
    func browserChrome(_ chrome: BrowserChromeView, submitted text: String)
    func browserChromeDidRequestBack(_ chrome: BrowserChromeView)
    func browserChromeDidRequestForward(_ chrome: BrowserChromeView)
    func browserChromeDidRequestReloadOrStop(_ chrome: BrowserChromeView)
    func browserChromeDidRequestShare(_ chrome: BrowserChromeView)
    func browserChromeDidRequestTabs(_ chrome: BrowserChromeView)
    func browserChrome(_ chrome: BrowserChromeView, requestedAdjacentTab offset: Int)
}

final class BrowserChromeView: UIView, UITextFieldDelegate {
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
    private var isLoading = false
    private var compactConstraint: NSLayoutConstraint!
    private var expandedConstraint: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func update(tab: BrowserTab, tabCount: Int) {
        if !addressField.isFirstResponder { addressField.text = tab.url?.absoluteString }
        backButton.isEnabled = tab.canGoBack
        forwardButton.isEnabled = tab.canGoForward
        isLoading = tab.isLoading
        reloadButton.setImage(UIImage(systemName: tab.isLoading ? "xmark" : "arrow.clockwise"), for: .normal)
        reloadButton.accessibilityLabel = tab.isLoading ? "Stop" : "Reload"
        tabsButton.accessibilityValue = "\(tabCount) tabs"
        lockView.isHidden = tab.url?.scheme?.lowercased() != "https"
        progressView.update(progress: tab.progress, loading: tab.isLoading)
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

        progressView.tintColor = .systemBlue
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
        addressField.placeholder = "Search or enter website"
        addressField.autocapitalizationType = .none
        addressField.autocorrectionType = .no
        addressField.keyboardType = .webSearch
        addressField.returnKeyType = .go
        addressField.clearButtonMode = .whileEditing
        addressField.delegate = self
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

    func textFieldDidBeginEditing(_ textField: UITextField) { animateEditing(true) }
    func textFieldDidEndEditing(_ textField: UITextField) { animateEditing(false) }

    private func animateEditing(_ editing: Bool) {
        compactConstraint.isActive = !editing
        expandedConstraint.isActive = editing
        let changes = { self.transform = editing ? CGAffineTransform(translationX: 0, y: -6) : .identity; self.layoutIfNeeded() }
        if UIAccessibility.isReduceMotionEnabled { changes() }
        else { UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.25, options: [.beginFromCurrentState], animations: changes) }
    }

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
