import os
import UIKit
import VulpraEngineKit

final class BrowserViewController: UIViewController, BrowserChromeViewDelegate, TabManagerDelegate,
    StartPageViewControllerDelegate, PageToolsControllerDelegate {
    private let logger = Logger(subsystem: "com.vulpra.browser", category: "browser")
    private let runtime: any EngineRuntime
    let tabManager: TabManager
    private let permissionController = BrowserPermissionController()
    private let promptController = BrowserPromptController()
    private let pageTools = PageToolsController()
    private let contextMenu = BrowserContextMenuController()
    private let contentContainer = UIView()
    let chrome = BrowserChromeView()
    private let startPage = StartPageViewController()
    private let suggestionsView = OmniboxSuggestionsView()
    private var attachedEngineView: UIView?
    private var failureView: VulpraEmptyStateView?
    private var privacyCover: UIVisualEffectView?
    private var recordedURLs: [UUID: String] = [:]
    private var initialURL: URL?
    private var isSceneActive = false
    private var suggestionWorkItem: DispatchWorkItem?
    private lazy var engineStartup = BrowserEngineStartupCoordinator(runtime: runtime)

    init(runtime: any EngineRuntime, initialURL: URL? = nil) {
        self.runtime = runtime
        tabManager = TabManager(runtime: runtime)
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
        showSelectedTab()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .browserSettingsDidChange, object: nil)
        scheduleInitialEnginePresentation()
    }

    /// After the engine gate opens, apply cold-start URL / restored tab sessions.
    private func scheduleInitialEnginePresentation() {
        engineStartup.start(localeIdentifier: Bundle.main.preferredLocalizations.first ?? "zh-Hans") { [weak self] in
            guard let self else { return }
            let pendingURL = self.initialURL
            self.initialURL = nil
            if let pendingURL {
                self.tabManager.selectedTab?.load(pendingURL, settings: BrowserSettingsStore.shared.value)
            }
            self.showSelectedTab()
        } onFailure: { [weak self] failure in
            self?.showFailure(failure, retry: { [weak self] in self?.scheduleInitialEnginePresentation() })
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        applyMemoryPressure(.heavy)
    }

    func applyMemoryPressure(_ level: TabManager.MemoryPressureLevel) {
        if level == .light { suggestionWorkItem?.cancel(); suggestionWorkItem = nil; suggestionsView.update([]) }
        tabManager.applyMemoryPressure(level)
    }

    func open(_ url: URL) {
        guard let tab = tabManager.selectedTab else { return }
        tab.load(url, settings: BrowserSettingsStore.shared.value)
        showSelectedTab()
    }

    func shutdown() {
        suggestionWorkItem?.cancel(); suggestionWorkItem = nil
        engineStartup.cancel()
        tabManager.shutdown()
        attachedEngineView?.removeFromSuperview()
        attachedEngineView = nil
    }

    func setActive(_ active: Bool) {
        isSceneActive = active
        tabManager.selectedTab?.setActive(active)
        updatePrivacyCover(show: !active && tabManager.selectedTab?.isPrivate == true)
    }

    private func configureOwners() {
        tabManager.delegate = self
        tabManager.permissionHandler = permissionController
        tabManager.clipboardPermissionHandler = permissionController
        tabManager.promptHandler = promptController
        permissionController.presenter = self
        promptController.presenter = self
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
        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            chrome.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            chrome.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            chrome.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            suggestionsView.leadingAnchor.constraint(equalTo: chrome.leadingAnchor),
            suggestionsView.trailingAnchor.constraint(equalTo: chrome.trailingAnchor),
            suggestionsView.bottomAnchor.constraint(equalTo: chrome.topAnchor, constant: -8),
            suggestionsView.heightAnchor.constraint(lessThanOrEqualToConstant: 320),
            suggestionsView.heightAnchor.constraint(equalToConstant: 290),
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
        if tab.lastFailure != nil { showFailure(for: tab); return }
        guard tab.url != nil else { showStartPage(); return }
        _ = tab.activate(settings: BrowserSettingsStore.shared.value)
        if tab.lastFailure != nil { showFailure(for: tab); return }
        guard let engineView = tab.engineView else { showStartPage(); return }
        guard attachedEngineView !== engineView else { return }
        attachedEngineView?.removeFromSuperview()
        attachedEngineView = nil
        clearFailureView()
        if startPage.parent === self {
            startPage.willMove(toParent: nil)
            startPage.view.removeFromSuperview()
            startPage.removeFromParent()
        }
        engineView.removeFromSuperview()
        engineView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(engineView)
        NSLayoutConstraint.activate([
            engineView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            engineView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            engineView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            engineView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        attachedEngineView = engineView
        logger.notice("Engine view attached")
        DispatchQueue.main.async { [weak self, weak tab] in
            guard let self, self.attachedEngineView === engineView else { return }; tab?.setActive(self.isSceneActive)
        }
    }
    private func showStartPage() {
        attachedEngineView?.removeFromSuperview()
        attachedEngineView = nil
        clearFailureView()
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
    private func showFailure(for tab: BrowserTab) {
        guard let failure = tab.lastFailure else { return }
        showFailure(failure, url: tab.url, retry: { [weak self, weak tab] in
            guard let self, let tab else { return }
            tab.retry(settings: BrowserSettingsStore.shared.value); self.showSelectedTab()
        }, useHTTP: tab.httpFallbackURL == nil ? nil : { [weak self, weak tab] in
            guard let self, let tab else { return }
            tab.loadHTTPFallback(settings: BrowserSettingsStore.shared.value); self.showSelectedTab()
        })
    }
    private func showFailure(_ failure: EngineFailure, url: URL? = nil,
                             retry: @escaping () -> Void, useHTTP: (() -> Void)? = nil) {
        logger.error("\(failure.code, privacy: .public): \(failure.message, privacy: .public)")
        attachedEngineView?.removeFromSuperview()
        attachedEngineView = nil
        if startPage.parent === self {
            startPage.willMove(toParent: nil)
            startPage.view.removeFromSuperview()
            startPage.removeFromParent()
        }
        clearFailureView()
        let state = VulpraEmptyStateView(
            symbol: "exclamationmark.triangle",
            title: VulpraL10n.text(failure.code == "navigation-failed" ? "browser.load_failure" : "engine.failure"),
            subtitle: url?.host,
            actionTitle: failure.isRecoverable ? VulpraL10n.text("common.retry") : nil,
            action: failure.isRecoverable ? retry : nil,
            secondaryActionTitle: useHTTP == nil ? nil : VulpraL10n.text("browser.use_http"),
            secondaryAction: useHTTP
        )
        state.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(state)
        NSLayoutConstraint.activate([
            state.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            state.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            state.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            state.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        failureView = state
    }
    private func clearFailureView() {
        failureView?.removeFromSuperview()
        failureView = nil
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

    func browserChrome(_ chrome: BrowserChromeView, submitted text: String) {
        suggestionWorkItem?.cancel(); suggestionWorkItem = nil
        suggestionsView.update([])
        let settings = BrowserSettingsStore.shared.value
        guard let resolution = OmniboxResolver.resolve(text, settings: settings),
              let tab = tabManager.selectedTab else { return }
        tab.load(resolution.url, settings: settings, httpFallbackURL: resolution.httpFallbackURL)
        showSelectedTab()
    }
    func browserChrome(_ chrome: BrowserChromeView, textDidChange text: String) {
        suggestionWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.chrome.addressField.text == text else { return }
            self.suggestionWorkItem = nil
            self.suggestionsView.update(OmniboxSuggestionProvider.suggestions(for: text, tabs: self.tabManager.tabs))
        }
        suggestionWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: work)
    }
    func browserChromeDidRequestBack(_ chrome: BrowserChromeView) { tabManager.selectedTab?.goBack() }
    func browserChromeDidRequestForward(_ chrome: BrowserChromeView) { tabManager.selectedTab?.goForward() }
    func browserChromeDidRequestReloadOrStop(_ chrome: BrowserChromeView) {
        guard let tab = tabManager.selectedTab else { return }; tab.isLoading ? tab.stop() : tab.reload()
    }
    func browserChromeDidRequestPageTools(_ chrome: BrowserChromeView) {
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
    func tabManagerDidChange(_ manager: TabManager) { showSelectedTab(); recordHistoryIfNeeded(for: manager.selectedTab) }
    func tabManager(_ manager: TabManager, didUpdatePresentationFor tab: BrowserTab) { updatePresentation(for: tab, in: manager) }
    func tabManager(_ manager: TabManager, didUpdatePersistableStateFor tab: BrowserTab) { updatePresentation(for: tab, in: manager) }
    func tabManager(_ manager: TabManager, didUpdateContentFor tab: BrowserTab) {
        guard tab === manager.selectedTab else { return }; showSelectedTab()
    }
    private func updatePresentation(for tab: BrowserTab, in manager: TabManager) {
        guard tab === manager.selectedTab else { return }; chrome.update(tab: tab, tabCount: manager.tabs.count)
        if !tab.isLoading { recordHistoryIfNeeded(for: tab) }
    }
    private func recordHistoryIfNeeded(for tab: BrowserTab?) {
        guard let tab, let url = tab.url, !tab.isLoading,
              recordedURLs[tab.id] != url.absoluteString else { return }
        recordedURLs[tab.id] = url.absoluteString
        HistoryStore.shared.record(title: tab.title, url: url, privateMode: tab.isPrivate)
    }
    func tabManager(_ manager: TabManager, requestedDownload response: EngineDownloadResponse,
                    completion: @escaping (Bool) -> Void) {
        completion(DownloadManager.shared.accept(response))
    }
    func tabManager(_ manager: TabManager, downloadAt path: String, received bytes: Int64) -> Bool { DownloadManager.shared.update(path: path, bytes: bytes) }
    func tabManager(_ manager: TabManager, completedDownloadAt path: String, succeeded: Bool) { DownloadManager.shared.complete(path: path, succeeded: succeeded) }
    func tabManager(_ manager: TabManager, requestedContextMenu element: EngineContextMenuElement) {
        contextMenu.present(element: element, from: self, sourceView: contentContainer)
    }
    func startPage(_ controller: StartPageViewController, open text: String) { browserChrome(chrome, submitted: text) }
    func startPageDidRequestPrivateTab(_ controller: StartPageViewController) { _ = tabManager.newTab(url: nil, privateMode: true); showSelectedTab() }
    func startPageDidRequestBookmarks(_ controller: StartPageViewController) { presentLibrary(.bookmarks) }
    func startPageDidRequestHistory(_ controller: StartPageViewController) { presentLibrary(.history) }
    func startPageDidRequestDownloads(_ controller: StartPageViewController) { presentNavigation(DownloadsViewController()) }
    func startPageDidRequestSettings(_ controller: StartPageViewController) {
        presentNavigation(SettingsViewController(runtime: runtime))
    }
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
    func pageToolsDidRequestDesktopMode(_ controller: PageToolsController) {
        BrowserSettingsStore.shared.update { $0.defaultDesktopMode.toggle() }
        tabManager.selectedTab?.applySettings(BrowserSettingsStore.shared.value)
        tabManager.selectedTab?.reload()
    }
    func pageTools(_ controller: PageToolsController, setZoom level: Int) {
        BrowserSettingsStore.shared.update { $0.pageZoom = level }
        tabManager.selectedTab?.applySettings(BrowserSettingsStore.shared.value)
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
