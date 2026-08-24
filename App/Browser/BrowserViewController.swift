import GeckoView
import os
import UIKit

final class BrowserViewController: UIViewController, BrowserChromeViewDelegate, TabManagerDelegate,
    StartPageViewControllerDelegate, PageToolsControllerDelegate {
    private let logger = Logger(subsystem: "com.vulpra.browser", category: "browser")
    let tabManager = TabManager()
    private let permissionController = BrowserPermissionController()
    private let promptController = BrowserPromptController()
    private let addonController = BrowserAddonController()
    let pageTools = PageToolsController()
    let pictureInPicture = BrowserPictureInPictureController()
    let readerMode = ReaderModeController()
    let contextMenu = BrowserContextMenuController()
    let contentContainer = UIView()
    let chrome = BrowserChromeView()
    let startPage = StartPageViewController()
    let suggestionsView = OmniboxSuggestionsView()
    private var attachedEngineView: UIView?
    private var privacyCover: UIVisualEffectView?
    var recordedURLs: [UUID: String] = [:]
    var initialURL: URL?
    private var isSceneActive = false
    private var failureOverlay: UIStackView?
    var findBar: FindInPageBar?
    /// Safari-style bottom dock: resting anchor vs keyboard-riding anchor.
    private var chromeBottomDock: NSLayoutConstraint?
    private var chromeBottomKeyboard: NSLayoutConstraint?
    /// Scroll-aware chrome: engine scroll telemetry drives visibility.
    private let scrollObserver = GeckoScrollObserver()
    private var lastScrollY: CGFloat = 0
    private var isChromeHidden = false
    var zoomPersistWork: DispatchWorkItem?

    init(initialURL: URL? = nil) {
        self.initialURL = initialURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureOwners()
        configureLayout()
        // Do not open Gecko windows in viewDidLoad. First-session open races
        // MainProcessInit/JS globals on device (AutoJSAPI::Init SIGSEGV).
        showSelectedTab()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: .browserSettingsDidChange, object: nil)
        scheduleInitialEnginePresentation()
    }

    /// After the engine gate opens, apply cold-start URL / restored tab sessions.
    private func scheduleInitialEnginePresentation() {
        let pendingURL = initialURL
        initialURL = nil
        GeckoEngineGate.whenReady { [weak self] in
            guard let self else { return }
            if let pendingURL {
                self.tabManager.selectedTab?.load(pendingURL, settings: BrowserSettingsStore.shared.value)
            }
            self.showSelectedTab()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        tabManager.suspendBackgroundTabs()
    }

    func setActive(_ active: Bool) {
        isSceneActive = active
        tabManager.selectedTab?.setActive(active)
        updatePrivacyCover(show: !active && tabManager.selectedTab?.isPrivate == true)
    }

    /// True while the home screen (not web content) fills the container.
    private var startPageVisible: Bool {
        attachedEngineView == nil
    }

    private func configureOwners() {
        tabManager.delegate = self
        tabManager.permissionDelegate = permissionController
        tabManager.promptDelegate = promptController
        permissionController.presenter = self
        promptController.presenter = self
        addonController.presenter = self
        addonController.tabManager = tabManager
        addonController.onOpenURL = { [weak self] in self?.open($0) }
        pageTools.delegate = self
        contextMenu.onOpenURL = { [weak self] in self?.open($0) }
        chrome.delegate = self
        startPage.delegate = self
        suggestionsView.onSelect = { [weak self] suggestion in
            guard let self else { return }; self.browserChrome(self.chrome, submitted: suggestion.value)
        }
        scrollObserver.onScrollY = { [weak self] y in
            self?.handleEngineScrollY(y)
        }
    }

    private func configureLayout() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        chrome.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)
        view.addSubview(chrome)
        view.insertSubview(suggestionsView, belowSubview: chrome)
        // Safari-style bottom dock: the page is full-bleed edge to edge and
        // the command capsule floats over its bottom. While the address field
        // is edited the capsule rides the keyboard, and the suggestion panel
        // (anchored above the capsule) rides with it.
        chromeBottomDock = chrome.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6)
        chromeBottomKeyboard = chrome.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8)
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            chrome.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            chrome.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            chromeBottomDock!,
            suggestionsView.bottomAnchor.constraint(equalTo: chrome.topAnchor, constant: -8),
            suggestionsView.leadingAnchor.constraint(equalTo: chrome.leadingAnchor),
            suggestionsView.trailingAnchor.constraint(equalTo: chrome.trailingAnchor),
            suggestionsView.heightAnchor.constraint(lessThanOrEqualToConstant: 320),
        ])

        let backEdge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeNavigation(_:)))
        backEdge.edges = .left
        contentContainer.addGestureRecognizer(backEdge)
        let forwardEdge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeNavigation(_:)))
        forwardEdge.edges = .right
        contentContainer.addGestureRecognizer(forwardEdge)
    }

    func showSelectedTab() {
        guard isViewLoaded, let tab = tabManager.selectedTab else { return }
        chrome.update(tab: tab, tabCount: tabManager.tabs.count)
        refreshToolsMenu()

        guard tab.url != nil else { showStartPage(); return }
        let session = tab.activate(settings: BrowserSettingsStore.shared.value)
        scrollObserver.attach(to: session)
        lastScrollY = 0
        // First activate may still be waiting on GeckoEngineGate — keep start page up.
        guard session.isOpen(), let engineView = session.engineView else {
            showStartPage()
            return
        }
        tab.setActive(isSceneActive)
        guard attachedEngineView !== engineView else { return }

        removeCurrentContent()
        pictureInPicture.attach(to: session)
        engineView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(engineView)
        NSLayoutConstraint.activate([
            engineView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            engineView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            engineView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            engineView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        attachedEngineView = engineView
        setChromeDisplayed(true)
    }

    private func showStartPage() {
        setChromeDisplayed(false)
        if attachedEngineView != nil { removeCurrentContent() }
        guard startPage.parent !== self else { return }
        addChild(startPage)
        startPage.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(startPage.view)
        NSLayoutConstraint.activate([
            startPage.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            startPage.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            startPage.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            startPage.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        startPage.didMove(toParent: self)
    }

    private func removeCurrentContent() {
        attachedEngineView?.removeFromSuperview()
        attachedEngineView = nil
        if startPage.parent === self {
            startPage.willMove(toParent: nil)
            startPage.view.removeFromSuperview()
            startPage.removeFromParent()
        }
    }

    private func showFailure(_ message: String) {
        logger.error("\(message, privacy: .public)")
        removeCurrentContent()
        let icon = UIImageView(image: UIImage(systemName: "wifi.exclamationmark"))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .center
        let label = UILabel()
        label.text = message
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .subheadline)
        var configuration = UIButton.Configuration.gray()
        configuration.title = L10n.tr("Try Again", "重试")
        configuration.image = UIImage(systemName: "arrow.clockwise")
        configuration.imagePadding = 6
        configuration.buttonSize = .large
        configuration.cornerStyle = .capsule
        let retry = UIButton(configuration: configuration)
        retry.addTarget(self, action: #selector(retryFailedPage), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [icon, label, retry])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(22, after: label)
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentContainer.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentContainer.layoutMarginsGuide.trailingAnchor),
            icon.heightAnchor.constraint(equalToConstant: 56),
            icon.widthAnchor.constraint(equalToConstant: 72),
        ])
    }

    @objc private func retryFailedPage() {
        attachedEngineView?.removeFromSuperview()
        attachedEngineView = nil
        tabManager.selectedTab?.reload()
        showSelectedTab()
    }

    func presentLibrary(_ section: LibrarySection) {
        let controller = LibraryViewController(section: section)
        controller.onOpenURL = { [weak self] in self?.open($0) }
        presentNavigation(controller)
    }

    func presentNavigation(_ controller: UIViewController) {
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close,
                                                                      target: self, action: #selector(closePresented))
        present(UINavigationController(rootViewController: controller), animated: true)
    }

    /// Start-page vs web mode: the bar exists only while web content shows.
    /// Appearance is animated — the bar drops in from beneath the status bar.
    func setChromeDisplayed(_ displayed: Bool) {
        let targetHidden = !displayed
        guard chrome.isHidden != targetHidden else { return }
        if targetHidden { dismissFindBar() }
        chrome.isHidden = targetHidden
        suggestionsView.isHidden = targetHidden
        if !targetHidden, !UIAccessibility.isReduceMotionEnabled {
            chrome.alpha = 0
            chrome.transform = CGAffineTransform(translationX: 0, y: 18)
            VulpraMotion.spring {
                self.chrome.alpha = 1
                self.chrome.transform = .identity
            }
        } else {
            chrome.alpha = 1
            chrome.transform = .identity
        }
    }

    /// Safari-style keyboard ride: while the address field is edited the
    /// capsule leaves its dock and sits on top of the keyboard; suggestions
    /// ride with it because they anchor to the capsule.
    func setChromeKeyboardRide(_ enabled: Bool) {
        guard let dock = chromeBottomDock, let ride = chromeBottomKeyboard else { return }
        guard ride.isActive != enabled else { return }
        if enabled {
            dock.isActive = false
            ride.isActive = true
        } else {
            ride.isActive = false
            dock.isActive = true
        }
        view.setNeedsLayout()
    }

    // MARK: - Scroll-aware chrome (Safari-style)

    private func hideChrome() {
        guard !isChromeHidden else { return }
        isChromeHidden = true
        dismissFindBar()
        animateChrome(hidden: true)
    }

    func showChrome() {
        guard isChromeHidden else { return }
        isChromeHidden = false
        animateChrome(hidden: false)
    }

    private func animateChrome(hidden: Bool) {
        if UIAccessibility.isReduceMotionEnabled {
            applyChromeState(hidden: hidden)
            return
        }
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.95,
                       initialSpringVelocity: 0.2, options: [.beginFromCurrentState]) {
            self.applyChromeState(hidden: hidden)
        }
    }

    private func applyChromeState(hidden: Bool) {
        chrome.alpha = hidden ? 0 : 1
        // Slide down beneath the home indicator; the page stays full-bleed.
        chrome.transform = hidden
            ? CGAffineTransform(translationX: 0, y: chrome.bounds.height + view.safeAreaInsets.bottom + 12)
            : .identity
        view.layoutIfNeeded()
    }

    /// Engine telemetry → direction detection. Scroll down hides the toolbar,
    /// scroll up brings it back — nothing ever overlays the page itself.
    func handleEngineScrollY(_ y: CGFloat) {
        defer { lastScrollY = y }
        guard !startPageVisible, isViewLoaded else { return }
        let dy = y - lastScrollY
        guard abs(dy) > 14 else { return }  // ignore rubber-band jitter
        if dy > 0, chrome.alpha > 0.5 {
            if chrome.addressField.isFirstResponder { chrome.addressField.resignFirstResponder() }
            suggestionsView.update([])
            hideChrome()
        } else if dy < 0, chrome.alpha < 0.5 {
            showChrome()
        }
    }

    private func updatePrivacyCover(show: Bool) {
        if show, privacyCover == nil {
            let cover = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
            cover.frame = view.bounds
            cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(cover)
            privacyCover = cover
        } else if !show {
            privacyCover?.removeFromSuperview()
            privacyCover = nil
        }
    }

    @objc private func settingsChanged() {
        overrideUserInterfaceStyle = BrowserSettingsStore.shared.value.darkAppearance ? .dark : .unspecified
        tabManager.tabs.forEach { $0.applySettings(BrowserSettingsStore.shared.value) }
    }
    @objc private func closePresented() { dismiss(animated: true) }
    @objc private func edgeNavigation(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended,
              gesture.translation(in: contentContainer).x.magnitude > 60 else { return }
        gesture.edges == .left ? tabManager.selectedTab?.goBack() : tabManager.selectedTab?.goForward()
    }
}
