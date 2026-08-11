import Foundation
import UIKit
import VulpraEngineKit

@MainActor
protocol TabManagerDelegate: AnyObject {
    func tabManagerDidChange(_ manager: TabManager)
    func tabManager(_ manager: TabManager, didUpdatePresentationFor tab: BrowserTab)
    func tabManager(_ manager: TabManager, didUpdatePersistableStateFor tab: BrowserTab)
    func tabManager(_ manager: TabManager, didUpdateContentFor tab: BrowserTab)
    func tabManager(_ manager: TabManager, requestedDownload response: EngineDownloadResponse,
                    completion: @escaping (Bool) -> Void)
    func tabManager(_ manager: TabManager, downloadAt path: String, received bytes: Int64) -> Bool
    func tabManager(_ manager: TabManager, completedDownloadAt path: String, succeeded: Bool)
    func tabManager(_ manager: TabManager, requestedContextMenu element: EngineContextMenuElement)
}

@MainActor
final class TabManager: BrowserTabObserver {
    private struct SavedTabs: Codable, Equatable { var selectedID: UUID?; var tabs: [BrowserTabRecord] }
    private let store = AtomicJSONStore<SavedTabs>(filename: "tabs.json")
    private let runtime: any EngineRuntime
    private var lastPersistedTabs: SavedTabs?
    private(set) var tabs: [BrowserTab] = []
    private(set) var selectedID: UUID?
    private(set) var recentlyClosed: [BrowserTabRecord] = []
    weak var delegate: TabManagerDelegate?
    weak var promptHandler: (any EnginePromptHandler)? {
        didSet { tabs.forEach { $0.promptHandler = promptHandler; $0.session?.promptHandler = promptHandler } }
    }
    weak var clipboardPermissionHandler: (any EngineClipboardPermissionHandler)? {
        didSet { tabs.forEach { $0.clipboardPermissionHandler = clipboardPermissionHandler; $0.session?.clipboardPermissionHandler = clipboardPermissionHandler } }
    }

    weak var permissionHandler: (any EnginePermissionHandler)? {
        didSet { tabs.forEach { $0.permissionHandler = permissionHandler; $0.session?.permissionHandler = permissionHandler } }
    }

    init(runtime: any EngineRuntime) {
        self.runtime = runtime
        let saved = store.load(default: SavedTabs(selectedID: nil, tabs: []))
        tabs = saved.tabs.filter { !$0.isPrivate }.map { BrowserTab(record: $0, runtime: runtime) }
        selectedID = tabs.contains(where: { $0.id == saved.selectedID }) ? saved.selectedID : tabs.first?.id
        lastPersistedTabs = SavedTabs(selectedID: selectedID, tabs: tabs.map(\.record))
        if tabs.isEmpty { _ = newTab(url: nil, privateMode: false, select: true) }
        tabs.forEach(configure)
    }

    var selectedTab: BrowserTab? { tabs.first { $0.id == selectedID } }
    var normalTabs: [BrowserTab] { tabs.filter { !$0.isPrivate } }
    var privateTabs: [BrowserTab] { tabs.filter(\.isPrivate) }

    @discardableResult
    func newTab(url: URL?, privateMode: Bool, select: Bool = true, windowID: String? = nil) -> BrowserTab {
        let tab = BrowserTab(url: url, isPrivate: privateMode, runtime: runtime)
        configure(tab); tabs.append(tab)
        if let windowID { _ = tab.activate(settings: BrowserSettingsStore.shared.value, windowID: windowID) }
        if select { selectedID = tab.id }
        changed(); return tab
    }

    @MainActor
    func select(_ tab: BrowserTab) {
        guard tabs.contains(where: { $0 === tab }) else { return }
        // Thumbnails refresh on page completion (BrowserTab), never on the
        // tab-switch path: select() must stay free of main-thread draw work.
        selectedTab?.setActive(false)
        selectedID = tab.id; tab.setActive(true); changed()
    }

    @MainActor
    func selectAdjacent(offset: Int) {
        guard let selectedID, let index = tabs.firstIndex(where: { $0.id == selectedID }), !tabs.isEmpty else { return }
        select(tabs[(index + offset + tabs.count) % tabs.count])
    }

    func close(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(where: { $0 === tab }) else { return }
        let wasSelected = tab.id == selectedID
        if !tab.isPrivate { recentlyClosed.insert(tab.record, at: 0); recentlyClosed = Array(recentlyClosed.prefix(20)) }
        tab.suspend(); tabs.remove(at: index)
        if tabs.isEmpty { _ = newTab(url: nil, privateMode: tab.isPrivate, select: true) }
        else if wasSelected { selectedID = tabs[min(index, tabs.count - 1)].id }
        changed()
    }

    func move(_ tab: BrowserTab, before target: BrowserTab) {
        guard tab !== target, let source = tabs.firstIndex(where: { $0 === tab }),
              let destination = tabs.firstIndex(where: { $0 === target }), tab.isPrivate == target.isPrivate else { return }
        tabs.remove(at: source); tabs.insert(tab, at: source < destination ? destination - 1 : destination); changed()
    }

    func closeOthers(keeping tab: BrowserTab) {
        tabs.filter { $0 !== tab && $0.isPrivate == tab.isPrivate }.forEach { $0.suspend() }
        tabs.removeAll { $0 !== tab && $0.isPrivate == tab.isPrivate }; selectedID = tab.id; changed()
    }

    func undoClose() {
        guard !recentlyClosed.isEmpty else { return }
        let tab = BrowserTab(record: recentlyClosed.removeFirst(), runtime: runtime)
        configure(tab); tabs.append(tab); selectedID = tab.id; changed()
    }

    enum MemoryPressureLevel { case light, heavy }

    /// Bounded live-session cap: selected tab + this many most-recent
    /// non-selected tabs keep live sessions under heavy memory pressure.
    static let keepActiveSessionCount = 3

    func applyMemoryPressure(_ level: MemoryPressureLevel) {
        let background = tabs.filter { $0.id != selectedID }.sorted { $0.lastAccess < $1.lastAccess }
        switch level {
        case .light:
            // Release decoded thumbnails and idle sessions; keep page state
            // fully alive (no session.close, no teardown).
            background.forEach { $0.releaseThumbnail(); $0.setActive(false) }
        case .heavy:
            // Full LRU teardown beyond the bounded cap. The selected tab is
            // never touched; the most-recent (cap-1) background tabs keep
            // their live sessions so tab switching stays fast.
            let keep = max(Self.keepActiveSessionCount - 1, 0)
            background.prefix(max(background.count - keep, 0)).forEach { $0.suspend() }
        }
    }

    private func suspendBackgroundTabs() { tabs.filter { $0.id != selectedID }.sorted { $0.lastAccess < $1.lastAccess }.forEach { $0.suspend() } }

    func shutdown() {
        tabs.forEach { $0.suspend() }
    }

    private func configure(_ tab: BrowserTab) {
        tab.observer = self; tab.permissionHandler = permissionHandler; tab.promptHandler = promptHandler
    }

    private func persistTabs() {
        let normal = tabs.filter { !$0.isPrivate }.map(\.record)
        let snapshot = SavedTabs(
            selectedID: normal.contains(where: { $0.id == selectedID }) ? selectedID : normal.first?.id,
            tabs: normal
        )
        if snapshot != lastPersistedTabs {
            lastPersistedTabs = snapshot
            store.save(snapshot)
        }
    }

    private func changed() {
        persistTabs()
        delegate?.tabManagerDidChange(self)
    }

    func browserTabPresentationDidChange(_ tab: BrowserTab) {
        delegate?.tabManager(self, didUpdatePresentationFor: tab)
    }
    func browserTabPersistableStateDidChange(_ tab: BrowserTab) {
        persistTabs()
        delegate?.tabManager(self, didUpdatePersistableStateFor: tab)
    }
    func browserTabContentDidChange(_ tab: BrowserTab) {
        delegate?.tabManager(self, didUpdateContentFor: tab)
    }
    func browserTabDidRequestClose(_ tab: BrowserTab) { close(tab) }
    func browserTabDidRequestFocus(_ tab: BrowserTab) { select(tab) }
    func browserTab(_ tab: BrowserTab, requestedNewTab url: URL, windowID: String) -> Bool {
        newTab(url: url, privateMode: tab.isPrivate, windowID: windowID).session != nil
    }
    func browserTab(_ tab: BrowserTab, requestedDownload response: EngineDownloadResponse,
                    completion: @escaping (Bool) -> Void) {
        delegate?.tabManager(self, requestedDownload: response, completion: completion) ?? completion(false)
    }
    func browserTab(_ tab: BrowserTab, downloadAt path: String, received bytes: Int64) -> Bool {
        delegate?.tabManager(self, downloadAt: path, received: bytes) ?? false
    }
    func browserTab(_ tab: BrowserTab, completedDownloadAt path: String, succeeded: Bool) {
        delegate?.tabManager(self, completedDownloadAt: path, succeeded: succeeded)
    }
    func browserTab(_ tab: BrowserTab, requestedContextMenu element: EngineContextMenuElement) {
        delegate?.tabManager(self, requestedContextMenu: element)
    }
}
