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
    private let contextMenu = BrowserContextMenuController()
    private let contentContainer = UIView()
    private let chrome = BrowserChromeView()
    private let startPage = StartPageViewController()
    private let suggestionsView = OmniboxSuggestionsView()
    private var attachedEngineView: UIView?
    private var privacyCover: UIVisualEffectView?
    private var recordedURLs: [UUID: String] = [:]
    private var initialURL: URL?
    private var isSceneActive = false

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
        if let initialURL {
            tabManager.selectedTab?.load(initialURL, settings: BrowserSettingsStore.shared.value)
            self.initialURL = nil
        }
        showSelectedTab()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: .browserSettingsDidChange, object: nil)
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

    private func showSelectedTab() {
        guard isViewLoaded, let tab = tabManager.selectedTab else { return }
        chrome.update(tab: tab, tabCount: tabManager.tabs.count)
        attachedEngineView?.removeFromSuperview()
        attachedEngineView = nil
        startPage.willMove(toParent: nil)
        startPage.view.removeFromSuperview()
        startPage.removeFromParent()

        guard tab.url != nil else { showStartPage(); return }
        let session = tab.activate(settings: BrowserSettingsStore.shared.value)
        pictureInPicture.attach(to: session)
        tab.setActive(isSceneActive)
        guard let engineView = session.engineView else { showFailure("Gecko engine view unavailable"); return }
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
    }

    private func showStartPage() {
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

    private func showFailure(_ message: String) {
        logger.error("\(message, privacy: .public)")
        let label = UILabel(); label.text = message; label.textColor = .secondaryLabel
        label.textAlignment = .center; label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: contentContainer.layoutMarginsGuide.leadingAnchor),
        ])
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
        guard let tab = manager.selectedTab, let url = tab.url, !tab.isLoading,
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
    func pageToolsDidRequestDesktopMode(_ controller: PageToolsController) {
        BrowserSettingsStore.shared.update { $0.defaultDesktopMode.toggle() }
        tabManager.selectedTab?.applySettings(BrowserSettingsStore.shared.value)
        tabManager.selectedTab?.reload()
    }
    func pageTools(_ controller: PageToolsController, setZoom level: Int) {
        BrowserSettingsStore.shared.update { $0.pageZoom = level }
        tabManager.selectedTab?.applySettings(BrowserSettingsStore.shared.value)
    }
    func pageToolsDidRequestPictureInPicture(_ controller: PageToolsController) { pictureInPicture.start() }
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
