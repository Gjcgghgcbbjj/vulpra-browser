import GeckoView
import os
import UIKit

final class BrowserViewController: UIViewController, BrowserChromeViewDelegate, TabManagerDelegate,
    StartPageViewControllerDelegate, PageToolsControllerDelegate {
    private let logger = Logger(subsystem: "com.vulpra.browser", category: "browser")
    private let tabManager = TabManager()
    private let permissionController = BrowserPermissionController()
    private let promptController = BrowserPromptController()
    private let addonController = BrowserAddonController()
    private let pageTools = PageToolsController()
    private let pictureInPicture = BrowserPictureInPictureController()
    private let readerMode = ReaderModeController()
    private let contextMenu = BrowserContextMenuController()
    private let contentContainer = UIView()
    private let chrome = BrowserChromeView()
    private let chromeTogglePill = UIButton(type: .custom)
    private let startPage = StartPageViewController()
    private let suggestionsView = OmniboxSuggestionsView()
    private var attachedEngineView: UIView?
    private var privacyCover: UIVisualEffectView?
    private var recordedURLs: [UUID: String] = [:]
    private var initialURL: URL?
    private var isSceneActive = false
    private var chromeDockConstraint: NSLayoutConstraint?
    private var chromeKeyboardConstraint: NSLayoutConstraint?
    private var chromeRidesKeyboard = false
    private var contentTopConstraint: NSLayoutConstraint?
    private var contentBottomToChrome: NSLayoutConstraint?
    private var contentBottomToSafe: NSLayoutConstraint?
    private var chromeHiddenForImmersive = false

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

    func open(_ url: URL) {
        guard let tab = tabManager.selectedTab else { return }
        tab.load(url, settings: BrowserSettingsStore.shared.value)
        showSelectedTab()
    }

    /// State restoration: restore multiple tabs from saved URLs.
    /// Called by SceneDelegate when the app is relaunched after a system kill.
    func restoreTabs(urls: [URL]) {
        guard !urls.isEmpty else { return }
        let settings = BrowserSettingsStore.shared.value
        // Load the first URL into the existing empty tab (created by TabManager.init).
        if let firstTab = tabManager.selectedTab, firstTab.url == nil {
            firstTab.load(urls[0], settings: settings)
        }
        // Create additional tabs for the remaining URLs.
        for url in urls.dropFirst() {
            tabManager.newTab(url: url, privateMode: false, select: false)
        }
        showSelectedTab()
    }

    /// State restoration: the URLs of all open normal (non-private) tabs.
    var openTabURLs: [URL] {
        tabManager.normalTabs.compactMap { $0.url }
    }

    func closePrivateTabs() { tabManager.closePrivateTabs() }

    func setActive(_ active: Bool) {
        isSceneActive = active
        tabManager.selectedTab?.setActive(active)
        updatePrivacyCover(show: !active && tabManager.selectedTab?.isPrivate == true)
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
    }

    private func configureLayout() {
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        chrome.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)
        view.addSubview(chrome)
        view.insertSubview(suggestionsView, belowSubview: chrome)
        chromeDockConstraint = chrome.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6)
        // Web content must never sit under the notch/status bar or behind the
        // floating toolbar — the Gecko uikit port exposes no safe-area insets
        // to pages, so fixed page footers/headers were getting occluded.
        // Top: below the safe area. Bottom: above the chrome while it is
        // visible; full height down to the home-indicator area in immersive
        // mode (the pill toggle).
        contentTopConstraint = contentContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        contentBottomToChrome = contentContainer.bottomAnchor.constraint(equalTo: chrome.topAnchor, constant: -8)
        contentBottomToSafe = contentContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            contentTopConstraint!,
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentBottomToChrome!,
            chrome.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            chrome.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            chromeDockConstraint!,
            suggestionsView.leadingAnchor.constraint(equalTo: chrome.leadingAnchor),
            suggestionsView.trailingAnchor.constraint(equalTo: chrome.trailingAnchor),
            suggestionsView.bottomAnchor.constraint(equalTo: chrome.topAnchor, constant: -8),
        ])
        // Height of the suggestion panel is driven by its intrinsicContentSize
        // (row count); no fixed 290pt panel for a single suggestion anymore.
        // When the address field is focused the chrome docks above the
        // keyboard so suggestions stay visible (Safari-style).
        chromeKeyboardConstraint = chrome.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8)

        // Immersive reading toggle: a subtle pill under the chrome. Tap hides
        // the whole toolbar so the page gets the full screen; tap again to
        // bring it back. No gesture conflicts with web content.
        chromeTogglePill.backgroundColor = UIColor.tertiarySystemFill
        chromeTogglePill.layer.cornerRadius = 2
        chromeTogglePill.accessibilityLabel = L10n.tr("Show toolbar", "显示工具栏")
        chromeTogglePill.isUserInteractionEnabled = true
        chromeTogglePill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chromeTogglePill)
        chromeTogglePill.addTarget(self, action: #selector(toggleChrome), for: .touchUpInside)
        NSLayoutConstraint.activate([
            chromeTogglePill.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            chromeTogglePill.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            chromeTogglePill.widthAnchor.constraint(equalToConstant: 28),
            chromeTogglePill.heightAnchor.constraint(equalToConstant: 4),
        ])
        chromeTogglePill.alpha = 0

        let backEdge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeNavigation(_:)))
        backEdge.edges = .left
        contentContainer.addGestureRecognizer(backEdge)
        let forwardEdge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgeNavigation(_:)))
        forwardEdge.edges = .right
        contentContainer.addGestureRecognizer(forwardEdge)
    }

    private func showSelectedTab() {
        guard isViewLoaded, let tab = tabManager.selectedTab else { return }
        chrome.update(tab: tab, tabCount: tabManager.tabs.count)

        guard tab.url != nil else { showStartPage(); return }
        let session = tab.activate(settings: BrowserSettingsStore.shared.value)
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
    }

    private func showStartPage() {
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

    private func presentLibrary(_ section: LibrarySection) {
        let controller = LibraryViewController(section: section)
        controller.onOpenURL = { [weak self] in self?.open($0) }
        presentNavigation(controller)
    }

    private func presentNavigation(_ controller: UIViewController) {
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close,
                                                                      target: self, action: #selector(closePresented))
        present(UINavigationController(rootViewController: controller), animated: true)
    }

    /// Docks the chrome above the keyboard while editing the address field.
    private func setChromeKeyboardRide(_ enabled: Bool) {        guard enabled != chromeRidesKeyboard,
              let dock = chromeDockConstraint, let ride = chromeKeyboardConstraint else { return }
        chromeRidesKeyboard = enabled
        view.layoutIfNeeded()
        let changes = {
            if enabled { dock.isActive = false; ride.isActive = true }
            else { ride.isActive = false; dock.isActive = true }
            self.view.layoutIfNeeded()
        }
        if UIAccessibility.isReduceMotionEnabled { changes() }
        else { UIView.animate(withDuration: 0.25, animations: changes) }
    }

    /// Immersive mode: hide or restore the bottom toolbar. The pill stays
    /// tappable so one tap always brings the chrome back. While hidden the
    /// page extends to the safe-area bottom (still clears the home indicator,
    /// since pages cannot read that inset themselves).
    @objc private func toggleChrome() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if chrome.addressField.isFirstResponder { chrome.addressField.resignFirstResponder() }
        let willHide = chrome.alpha > 0.5
        suggestionsView.update([])
        chromeHiddenForImmersive = willHide
        view.layoutIfNeeded()
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.92,
                       initialSpringVelocity: 0.3, options: [.beginFromCurrentState]) {
            self.chrome.alpha = willHide ? 0 : 1
            self.chrome.transform = willHide
                ? CGAffineTransform(translationX: 0, y: self.chrome.bounds.height + 20)
                : .identity
            // Swap the content bottom edge with the chrome state.
            self.contentBottomToChrome?.isActive = !willHide
            self.contentBottomToSafe?.isActive = willHide
            // The restore pill only exists while hidden, parked in the corner
            // away from the thumb-rest zone so browsing taps never hit it.
            self.chromeTogglePill.alpha = willHide ? 0.55 : 0
            self.view.layoutIfNeeded()
        }
    }

    func browserChromeDidBeginEditing(_ chrome: BrowserChromeView) { setChromeKeyboardRide(true) }
    func browserChromeDidEndEditing(_ chrome: BrowserChromeView) { setChromeKeyboardRide(false) }

    func browserChrome(_ chrome: BrowserChromeView, submitted text: String) {
        suggestionsView.update([])
        guard let url = OmniboxResolver.resolve(text, settings: BrowserSettingsStore.shared.value) else { return }
        open(url)
    }
    func browserChrome(_ chrome: BrowserChromeView, textDidChange text: String) {
        suggestionsView.update(OmniboxSuggestionProvider.suggestions(for: text, tabs: tabManager.tabs))
    }
    func browserChromeDidRequestBack(_ chrome: BrowserChromeView) { tabManager.selectedTab?.goBack() }
    func browserChromeDidRequestForward(_ chrome: BrowserChromeView) { tabManager.selectedTab?.goForward() }
    func browserChromeDidRequestReloadOrStop(_ chrome: BrowserChromeView) {
        guard let tab = tabManager.selectedTab else { return }; tab.isLoading ? tab.stop() : tab.reload()
    }
    func browserChromeDidRequestShare(_ chrome: BrowserChromeView) {
        pageTools.present(from: self, sourceView: chrome, url: tabManager.selectedTab?.url)
    }
    func browserChromeDidRequestTabs(_ chrome: BrowserChromeView) {
        let overview = TabOverviewViewController(manager: tabManager)
        overview.onDismiss = { [weak self] in self?.showSelectedTab() }
        present(UINavigationController(rootViewController: overview), animated: true)
    }
    func browserChrome(_ chrome: BrowserChromeView, requestedAdjacentTab offset: Int) {
        tabManager.selectAdjacent(offset: offset); showSelectedTab()
    }

    func tabManagerDidChange(_ manager: TabManager) {
        showSelectedTab()
        recordHistoryIfNeeded(for: manager.selectedTab)
    }
    func tabManager(_ manager: TabManager, didUpdatePresentationFor tab: BrowserTab) {
        guard tab === manager.selectedTab else { return }
        chrome.update(tab: tab, tabCount: manager.tabs.count)
        if !tab.isLoading { recordHistoryIfNeeded(for: tab) }
    }
    func tabManager(_ manager: TabManager, didUpdatePersistableStateFor tab: BrowserTab) {
        guard tab === manager.selectedTab else { return }
        chrome.update(tab: tab, tabCount: manager.tabs.count)
        if !tab.isLoading { recordHistoryIfNeeded(for: tab) }
    }
    func tabManager(_ manager: TabManager, didChangeSessionFor tab: BrowserTab) {
        guard tab === manager.selectedTab else { return }
        showSelectedTab()
    }

    private func recordHistoryIfNeeded(for tab: BrowserTab?) {
        guard let tab, let url = tab.url, !tab.isLoading,
              recordedURLs[tab.id] != url.absoluteString else { return }
        recordedURLs[tab.id] = url.absoluteString
        HistoryStore.shared.record(title: tab.title, url: url, privateMode: tab.isPrivate)
    }
    func tabManager(_ manager: TabManager, requestedDownload response: ExternalResponseInfo) async -> Bool { DownloadManager.shared.accept(response) }
    func tabManager(_ manager: TabManager, downloadAt path: String, received bytes: Int64) -> Bool { DownloadManager.shared.update(path: path, bytes: bytes) }
    func tabManager(_ manager: TabManager, completedDownloadAt path: String, succeeded: Bool) { DownloadManager.shared.complete(path: path, succeeded: succeeded) }
    func tabManager(_ manager: TabManager, requestedContextMenu element: ContextElement) {
        contextMenu.present(element: element, from: self, sourceView: contentContainer)
    }

    func startPage(_ controller: StartPageViewController, open text: String) { browserChrome(chrome, submitted: text) }
    func startPageDidRequestPrivateTab(_ controller: StartPageViewController) { _ = tabManager.newTab(url: nil, privateMode: true); showSelectedTab() }
    func startPageDidRequestBookmarks(_ controller: StartPageViewController) { presentLibrary(.bookmarks) }
    func startPageDidRequestHistory(_ controller: StartPageViewController) { presentLibrary(.history) }
    func startPageDidRequestDownloads(_ controller: StartPageViewController) { presentNavigation(DownloadsViewController()) }
    func startPageDidRequestSettings(_ controller: StartPageViewController) { presentNavigation(SettingsViewController()) }

    func pageToolsDidRequestShare(_ controller: PageToolsController) {
        guard let url = tabManager.selectedTab?.url else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = chrome
        present(activity, animated: true)
    }
    func pageToolsDidRequestBookmark(_ controller: PageToolsController) {
        guard let tab = tabManager.selectedTab, let url = tab.url else { return }
        BookmarkStore.shared.add(title: tab.title, url: url)
    }
    func pageTools(_ controller: PageToolsController, find text: String) {
        guard !text.isEmpty, let finder = tabManager.selectedTab?.session?.finder else { return }
        Task { _ = try? await finder.find(text); finder.setDisplayOptions([.highlightAll, .dimPage]) }
    }
    private var zoomPersistWork: DispatchWorkItem?

    func pageToolsDidRequestDesktopMode(_ controller: PageToolsController) {
        BrowserSettingsStore.shared.update { $0.defaultDesktopMode.toggle() }
        tabManager.selectedTab?.applySettings(BrowserSettingsStore.shared.value)
        tabManager.selectedTab?.reload()
    }
    func pageTools(_ controller: PageToolsController, setZoom level: Int) {
        // #1: Silent update (no broadcast), apply to selected tab only, debounce disk write.
        BrowserSettingsStore.shared.updateSilently { $0.pageZoom = level }
        tabManager.selectedTab?.applySettings(BrowserSettingsStore.shared.value)
        zoomPersistWork?.cancel()
        let work = DispatchWorkItem { BrowserSettingsStore.shared.persist() }
        zoomPersistWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    func pageToolsDidRequestPictureInPicture(_ controller: PageToolsController) { pictureInPicture.start() }
    /// Entering immersive from the page menu is deliberate; no tap-to-hide.
    func pageToolsDidRequestImmersiveMode(_ controller: PageToolsController) {
        if chrome.alpha > 0.5 { toggleChrome() }
    }
    func pageToolsDidRequestReaderMode(_ controller: PageToolsController) {
        guard let session = tabManager.selectedTab?.session else { return }
        readerMode.presenter = self
        Task { await readerMode.parseAndPresent(session: session, sourceView: chrome) }
    }
    func pageToolsDidRequestQRScanner(_ controller: PageToolsController) {
        let scanner = QRScannerViewController(); scanner.onCode = { [weak self] value in
            guard let self else { return }; self.browserChrome(self.chrome, submitted: value)
        }
        present(UINavigationController(rootViewController: scanner), animated: true)
    }

    private func updatePrivacyCover(show: Bool) {
        if show, privacyCover == nil {
            let cover = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
            cover.frame = view.bounds; cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(cover); privacyCover = cover
        } else if !show { privacyCover?.removeFromSuperview(); privacyCover = nil }
    }

    @objc private func settingsChanged() {
        overrideUserInterfaceStyle = BrowserSettingsStore.shared.value.darkAppearance ? .dark : .unspecified
        tabManager.tabs.forEach { $0.applySettings(BrowserSettingsStore.shared.value) }
    }
    @objc private func closePresented() { dismiss(animated: true) }
    @objc private func edgeNavigation(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended, gesture.translation(in: contentContainer).x.magnitude > 60 else { return }
        gesture.edges == .left ? tabManager.selectedTab?.goBack() : tabManager.selectedTab?.goForward()
    }
}
