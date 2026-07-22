import Foundation
import GeckoView
import UIKit

protocol TabManagerDelegate: AnyObject {
    func tabManagerDidChange(_ manager: TabManager)
    func tabManager(_ manager: TabManager, requestedDownload response: ExternalResponseInfo) async -> Bool
    func tabManager(_ manager: TabManager, downloadAt path: String, received bytes: Int64) -> Bool
    func tabManager(_ manager: TabManager, completedDownloadAt path: String, succeeded: Bool)
    func tabManager(_ manager: TabManager, requestedContextMenu element: ContextElement)
}

final class TabManager: BrowserTabObserver {
    private static let maximumRestoredTabs = 100
    private static let maximumLiveBackgroundSessions = 6
    private static let maximumCachedThumbnails = 12
    private struct SavedTabs: Codable { var selectedID: UUID?; var tabs: [BrowserTabRecord] }
    private let store = AtomicJSONStore<SavedTabs>(filename: "tabs.json")
    private var pendingMetadataPersistence: DispatchWorkItem?
    private(set) var tabs: [BrowserTab] = []
    private(set) var selectedID: UUID?
    private(set) var recentlyClosed: [BrowserTabRecord] = []
    weak var delegate: TabManagerDelegate?
    var promptDelegate: PromptDelegate? {
        didSet { tabs.forEach { $0.promptDelegate = promptDelegate; $0.session?.promptDelegate = promptDelegate } }
    }
    var permissionDelegate: PermissionEmbedderDelegate? {
        didSet { tabs.forEach { $0.permissionDelegate = permissionDelegate; $0.session?.permissionDelegate = permissionDelegate } }
    }

    init() {
        let saved = store.load(default: SavedTabs(selectedID: nil, tabs: []))
        tabs = saved.tabs.filter { !$0.isPrivate }.prefix(Self.maximumRestoredTabs).map(BrowserTab.init(record:))
        selectedID = tabs.contains(where: { $0.id == saved.selectedID }) ? saved.selectedID : tabs.first?.id
        if tabs.isEmpty { _ = newTab(url: nil, privateMode: false, select: true) }
        tabs.forEach(configure)
    }

    var selectedTab: BrowserTab? { tabs.first { $0.id == selectedID } }
    var normalTabs: [BrowserTab] { tabs.filter { !$0.isPrivate } }
    var privateTabs: [BrowserTab] { tabs.filter(\.isPrivate) }

    @discardableResult
    func newTab(url: URL?, privateMode: Bool, select: Bool = true, windowID: String? = nil) -> BrowserTab {
        let tab = BrowserTab(url: url, isPrivate: privateMode)
        configure(tab)
        tabs.append(tab)
        if let windowID { _ = tab.activate(settings: BrowserSettingsStore.shared.value, windowID: windowID) }
        if select { selectedID = tab.id }
        enforceSessionBudget()
        changed()
        return tab
    }

    func select(_ tab: BrowserTab) {
        guard tabs.contains(where: { $0 === tab }) else { return }
        selectedTab?.captureThumbnail()
        selectedTab?.setActive(false)
        selectedID = tab.id
        tab.markAccessed()
        tab.setActive(true)
        enforceSessionBudget()
        enforceThumbnailBudget()
        changed()
    }

    func selectAdjacent(offset: Int) {
        guard let selectedID, let index = tabs.firstIndex(where: { $0.id == selectedID }), !tabs.isEmpty else { return }
        let next = (index + offset + tabs.count) % tabs.count
        select(tabs[next])
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0 === tab }) else { return }
        let wasSelected = tab.id == selectedID
        if !tab.isPrivate {
            recentlyClosed.insert(tab.record, at: 0)
            recentlyClosed = Array(recentlyClosed.prefix(20))
        }
        tab.suspend()
        tabs.remove(at: index)
        if tabs.isEmpty { _ = newTab(url: nil, privateMode: tab.isPrivate, select: true) }
        else if wasSelected { selectedID = tabs[min(index, tabs.count - 1)].id }
        changed()
    }

    func move(_ tab: BrowserTab, before target: BrowserTab) {
        guard tab !== target, let source = tabs.firstIndex(where: { $0 === tab }),
              let destination = tabs.firstIndex(where: { $0 === target }),
              tab.isPrivate == target.isPrivate else { return }
        tabs.remove(at: source)
        tabs.insert(tab, at: source < destination ? destination - 1 : destination)
        changed()
    }

    func closeOthers(keeping tab: BrowserTab) {
        tabs.filter { $0 !== tab && $0.isPrivate == tab.isPrivate }.forEach { $0.suspend() }
        tabs.removeAll { $0 !== tab && $0.isPrivate == tab.isPrivate }
        selectedID = tab.id
        changed()
    }

    func undoClose() {
        guard !recentlyClosed.isEmpty else { return }
        let record = recentlyClosed.removeFirst()
        let tab = BrowserTab(record: record)
        configure(tab)
        tabs.append(tab)
        selectedID = tab.id
        changed()
    }

    func suspendBackgroundTabs() {
        tabs.filter { $0.id != selectedID }.sorted { $0.lastAccess < $1.lastAccess }.forEach { $0.suspend() }
    }

    func releaseMemoryPressure() {
        suspendBackgroundTabs()
        tabs.filter { $0.id != selectedID }.forEach { $0.discardThumbnail() }
    }

    func closePrivateTabs() {
        privateTabs.forEach { $0.suspend() }
        tabs.removeAll(where: \.isPrivate)
        if selectedTab == nil { selectedID = normalTabs.first?.id }
        if tabs.isEmpty { _ = newTab(url: nil, privateMode: false, select: true) }
        changed()
    }

    private func configure(_ tab: BrowserTab) {
        tab.observer = self
        tab.permissionDelegate = permissionDelegate
        tab.promptDelegate = promptDelegate
    }

    private func changed(persistImmediately: Bool = true) {
        if persistImmediately {
            pendingMetadataPersistence?.cancel()
            pendingMetadataPersistence = nil
            persist()
        } else {
            scheduleMetadataPersistence()
        }
        delegate?.tabManagerDidChange(self)
    }

    private func persist() {
        let normal = tabs.filter { !$0.isPrivate }.map(\.record)
        store.save(SavedTabs(selectedID: normal.contains(where: { $0.id == selectedID }) ? selectedID : normal.first?.id, tabs: normal))
    }

    private func scheduleMetadataPersistence() {
        pendingMetadataPersistence?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingMetadataPersistence = nil
            self.persist()
        }
        pendingMetadataPersistence = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func enforceSessionBudget() {
        let background = tabs
            .filter { $0.id != selectedID && $0.session != nil }
            .sorted { $0.lastAccess > $1.lastAccess }
        background.dropFirst(Self.maximumLiveBackgroundSessions).forEach { $0.suspend() }
    }

    private func enforceThumbnailBudget() {
        let cached = tabs
            .filter { $0.thumbnail != nil }
            .sorted { $0.lastAccess > $1.lastAccess }
        cached.dropFirst(Self.maximumCachedThumbnails).forEach { $0.discardThumbnail() }
    }

    func browserTabDidChange(_ tab: BrowserTab) { changed(persistImmediately: false) }
    func browserTabDidRequestClose(_ tab: BrowserTab) { close(tab) }

    func browserTab(_ tab: BrowserTab, requestedNewTab url: URL, windowID: String) -> GeckoSession? {
        newTab(url: url, privateMode: tab.isPrivate, windowID: windowID).session
    }

    func browserTab(_ tab: BrowserTab, requestedDownload response: ExternalResponseInfo) async -> Bool {
        await delegate?.tabManager(self, requestedDownload: response) ?? false
    }

    func browserTab(_ tab: BrowserTab, downloadAt path: String, received bytes: Int64) -> Bool {
        delegate?.tabManager(self, downloadAt: path, received: bytes) ?? false
    }

    func browserTab(_ tab: BrowserTab, completedDownloadAt path: String, succeeded: Bool) {
        delegate?.tabManager(self, completedDownloadAt: path, succeeded: succeeded)
    }

    func browserTab(_ tab: BrowserTab, requestedContextMenu element: ContextElement) {
        delegate?.tabManager(self, requestedContextMenu: element)
    }
}
