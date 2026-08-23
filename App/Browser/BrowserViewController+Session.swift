import UIKit

// MARK: - External URL entry and restoration

extension BrowserViewController {
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
}
