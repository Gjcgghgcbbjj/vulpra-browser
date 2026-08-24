import GeckoView
import UIKit

// MARK: - User-facing shell routing

extension BrowserViewController {
    func browserChromeDidBeginEditing(_ chrome: BrowserChromeView) {
        // Editing implies the bar must be visible, whatever the scroll state,
        // and it must ride the keyboard (Safari-style bottom dock).
        showChrome()
        setChromeKeyboardRide(true)
    }

    func browserChromeDidEndEditing(_ chrome: BrowserChromeView) {
        setChromeKeyboardRide(false)
        suggestionsView.update([])
    }

    func browserChrome(_ chrome: BrowserChromeView, submitted text: String) {
        suggestionsView.update([])
        guard let url = OmniboxResolver.resolve(text, settings: BrowserSettingsStore.shared.value) else { return }
        open(url)
    }

    func browserChrome(_ chrome: BrowserChromeView, textDidChange text: String) {
        suggestionsView.update(OmniboxSuggestionProvider.suggestions(for: text, tabs: tabManager.tabs))
    }

    func browserChromeDidRequestTabs(_ chrome: BrowserChromeView) {
        presentTabsOverview()
    }

    func browserChrome(_ chrome: BrowserChromeView, requestedAdjacentTab offset: Int) {
        tabManager.selectAdjacent(offset: offset)
        showSelectedTab()
    }

    func startPage(_ controller: StartPageViewController, open text: String) {
        browserChrome(chrome, submitted: text)
    }

    func startPageDidRequestPrivateTab(_ controller: StartPageViewController) {
        _ = tabManager.newTab(url: nil, privateMode: true)
        showSelectedTab()
    }
    func startPageDidRequestBookmarks(_ controller: StartPageViewController) { presentLibrary(.bookmarks) }
    func startPageDidRequestHistory(_ controller: StartPageViewController) { presentLibrary(.history) }
    func startPageDidRequestDownloads(_ controller: StartPageViewController) { presentNavigation(DownloadsViewController()) }
    func startPageDidRequestSettings(_ controller: StartPageViewController) { presentNavigation(SettingsViewController()) }

    // MARK: Command menu (system UIMenu, rebuilt on every tab state change)

    /// Rebuilds the ⋯ menu so the system always presents live navigation,
    /// page, and zoom state. Cheap enough to call on every presentation tick.
    func refreshToolsMenu() {
        guard let tab = tabManager.selectedTab else {
            chrome.updateToolsMenu(nil)
            return
        }
        let menu = pageTools.menu(url: tab.url,
                                  isLoading: tab.isLoading,
                                  canGoBack: tab.canGoBack,
                                  canGoForward: tab.canGoForward,
                                  zoomLevel: BrowserSettingsStore.shared.value.pageZoom,
                                  isPinnedToHome: tab.url.map { PinnedSitesStore.shared.contains(url: $0) } ?? false)
        chrome.updateToolsMenu(menu)
    }

    func pageToolsDidRequestPrivateTab(_ controller: PageToolsController) {
        _ = tabManager.newTab(url: nil, privateMode: true)
        showSelectedTab()
    }
    func pageToolsDidRequestBookmarks(_ controller: PageToolsController) { presentLibrary(.bookmarks) }
    func pageToolsDidRequestHistory(_ controller: PageToolsController) { presentLibrary(.history) }
    func pageToolsDidRequestDownloads(_ controller: PageToolsController) { presentNavigation(DownloadsViewController()) }
    func pageToolsDidRequestSettings(_ controller: PageToolsController) { presentNavigation(SettingsViewController()) }
    func pageToolsDidRequestGoBack(_ controller: PageToolsController) { tabManager.selectedTab?.goBack() }
    func pageToolsDidRequestGoForward(_ controller: PageToolsController) { tabManager.selectedTab?.goForward() }
    func pageToolsDidRequestReloadOrStop(_ controller: PageToolsController) {
        guard let tab = tabManager.selectedTab else { return }
        tab.isLoading ? tab.stop() : tab.reload()
    }

    func pageToolsDidRequestShare(_ controller: PageToolsController) {
        guard let url = tabManager.selectedTab?.url else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = chrome
        activity.popoverPresentationController?.sourceRect = chrome.bounds
        present(activity, animated: true)
    }

    func pageToolsDidRequestBookmark(_ controller: PageToolsController) {
        guard let tab = tabManager.selectedTab, let url = tab.url else { return }
        BookmarkStore.shared.add(title: tab.title, url: url)
    }

    func pageToolsDidRequestTogglePinToHome(_ controller: PageToolsController) {
        guard let tab = tabManager.selectedTab, let url = tab.url else { return }
        if PinnedSitesStore.shared.contains(url: url) {
            PinnedSitesStore.shared.unpin(url: url)
        } else {
            PinnedSitesStore.shared.pin(title: tab.title, url: url)
        }
    }

    func pageToolsDidRequestDesktopMode(_ controller: PageToolsController) {
        BrowserSettingsStore.shared.update { $0.defaultDesktopMode.toggle() }
        tabManager.selectedTab?.applySettings(BrowserSettingsStore.shared.value)
        tabManager.selectedTab?.reload()
    }

    func pageTools(_ controller: PageToolsController, setZoom level: Int) {
        // Silent update applies to the selected tab only; disk persistence is debounced.
        BrowserSettingsStore.shared.updateSilently { $0.pageZoom = level }
        tabManager.selectedTab?.applySettings(BrowserSettingsStore.shared.value)
        zoomPersistWork?.cancel()
        let work = DispatchWorkItem { BrowserSettingsStore.shared.persist() }
        zoomPersistWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        refreshToolsMenu()
    }

    func pageToolsDidRequestPictureInPicture(_ controller: PageToolsController) {
        pictureInPicture.start()
    }

    func pageToolsDidRequestReaderMode(_ controller: PageToolsController) {
        guard let session = tabManager.selectedTab?.session else { return }
        readerMode.presenter = self
        Task { await readerMode.parseAndPresent(session: session, sourceView: chrome) }
    }

    func pageToolsDidRequestQRScanner(_ controller: PageToolsController) {
        let scanner = QRScannerViewController()
        scanner.onCode = { [weak self] value in
            guard let self else { return }
            self.browserChrome(self.chrome, submitted: value)
        }
        present(UINavigationController(rootViewController: scanner), animated: true)
    }

    // MARK: Find in page

    func pageToolsDidRequestFindInPage(_ controller: PageToolsController) {
        presentFindBar()
    }

    func presentFindBar() {
        guard let session = tabManager.selectedTab?.session, session.isOpen() else { return }
        session.finder.setDisplayOptions([.highlightAll, .dimPage])

        let bar: FindInPageBar
        if let existing = findBar {
            bar = existing
        } else {
            bar = FindInPageBar()
            findBar = bar
            view.insertSubview(bar, aboveSubview: contentContainer)
            NSLayoutConstraint.activate([
                bar.bottomAnchor.constraint(equalTo: chrome.topAnchor, constant: -8),
                bar.leadingAnchor.constraint(equalTo: chrome.leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: chrome.trailingAnchor),
            ])
            bar.onTextChange = { [weak self] text in
                self?.runFind(text, direction: .forward)
            }
            bar.onNext = { [weak self] in self?.stepFind(.forward) }
            bar.onPrevious = { [weak self] in self?.stepFind(.backward) }
            bar.onClose = { [weak self] in self?.dismissFindBar() }
        }

        bar.transform = CGAffineTransform(translationX: 0, y: 16)
        bar.alpha = 0
        VulpraMotion.spring {
            bar.transform = .identity
            bar.alpha = 1
        }
        bar.focus()
    }

    func dismissFindBar() {
        guard let bar = findBar else { return }
        findBar = nil
        tabManager.selectedTab?.session?.finder.clear()
        bar.endEditing(true)
        VulpraMotion.settle(duration: 0.22) {
            bar.transform = CGAffineTransform(translationX: 0, y: 16)
            bar.alpha = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { bar.removeFromSuperview() }
    }

    private func runFind(_ text: String, direction: FindInPageDirection) {
        guard !text.isEmpty, let finder = tabManager.selectedTab?.session?.finder else {
            findBar?.update(count: 0, current: 0)
            return
        }
        finder.setDisplayOptions([.highlightAll, .dimPage])
        Task { [weak self] in
            guard let result = try? await finder.find(text, direction: direction) else { return }
            self?.findBar?.update(count: max(result.total, 0), current: max(result.current, 0))
        }
    }

    private func stepFind(_ direction: FindInPageDirection) {
        guard let text = findBar?.textForSearch, !text.isEmpty,
              let finder = tabManager.selectedTab?.session?.finder else { return }
        Task { [weak self] in
            guard let result = try? await finder.find(text, direction: direction) else { return }
            self?.findBar?.update(count: max(result.total, 0), current: max(result.current, 0))
        }
    }
}

// MARK: - Tab truth routing

extension BrowserViewController {
    func tabManagerDidChange(_ manager: TabManager) {
        showSelectedTab()
        recordHistoryIfNeeded(for: manager.selectedTab)
    }

    func tabManager(_ manager: TabManager, didUpdatePresentationFor tab: BrowserTab) {
        guard tab === manager.selectedTab else { return }
        chrome.update(tab: tab, tabCount: manager.tabs.count)
        refreshToolsMenu()
        if !tab.isLoading { recordHistoryIfNeeded(for: tab) }
    }

    func tabManager(_ manager: TabManager, didUpdatePersistableStateFor tab: BrowserTab) {
        guard tab === manager.selectedTab else { return }
        chrome.update(tab: tab, tabCount: manager.tabs.count)
        refreshToolsMenu()
        if !tab.isLoading { recordHistoryIfNeeded(for: tab) }
    }

    func tabManager(_ manager: TabManager, didChangeSessionFor tab: BrowserTab) {
        guard tab === manager.selectedTab else { return }
        dismissFindBar()
        showSelectedTab()
    }

    func tabManager(_ manager: TabManager, requestedDownload response: ExternalResponseInfo) async -> Bool {
        DownloadManager.shared.accept(response)
    }

    func tabManager(_ manager: TabManager, downloadAt path: String, received bytes: Int64) -> Bool {
        DownloadManager.shared.update(path: path, bytes: bytes)
    }

    func tabManager(_ manager: TabManager, completedDownloadAt path: String, succeeded: Bool) {
        DownloadManager.shared.complete(path: path, succeeded: succeeded)
    }

    func tabManager(_ manager: TabManager, requestedContextMenu element: ContextElement) {
        contextMenu.present(element: element, from: self, sourceView: contentContainer)
    }

    private func recordHistoryIfNeeded(for tab: BrowserTab?) {
        guard let tab, let url = tab.url, !tab.isLoading,
              recordedURLs[tab.id] != url.absoluteString else { return }
        recordedURLs[tab.id] = url.absoluteString
        HistoryStore.shared.record(title: tab.title, url: url, privateMode: tab.isPrivate)
    }
}
