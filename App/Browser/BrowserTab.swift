import Foundation
import GeckoView
import UIKit

struct BrowserTabRecord: Codable, Equatable {
    let id: UUID
    var url: String?
    var title: String
    var isPrivate: Bool
    var lastAccess: Date
}

protocol BrowserTabObserver: AnyObject {
    func browserTabDidChange(_ tab: BrowserTab)
    func browserTabDidRequestClose(_ tab: BrowserTab)
    func browserTab(_ tab: BrowserTab, requestedNewTab url: URL, windowID: String) -> GeckoSession?
    func browserTab(_ tab: BrowserTab, requestedDownload response: ExternalResponseInfo) async -> Bool
    func browserTab(_ tab: BrowserTab, downloadAt path: String, received bytes: Int64) -> Bool
    func browserTab(_ tab: BrowserTab, completedDownloadAt path: String, succeeded: Bool)
}

final class BrowserTab: NavigationDelegate, ProgressDelegate, ContentDelegate {
    let id: UUID
    let isPrivate: Bool
    weak var observer: BrowserTabObserver?
    private(set) var session: GeckoSession?
    private(set) var url: URL?
    private(set) var title: String
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var progress = 0
    private(set) var isLoading = false
    private(set) var lastAccess: Date
    var permissionDelegate: PermissionEmbedderDelegate?
    var promptDelegate: PromptDelegate?

    init(record: BrowserTabRecord) {
        id = record.id
        isPrivate = record.isPrivate
        url = record.url.flatMap(URL.init(string:))
        title = record.title
        lastAccess = record.lastAccess
    }

    convenience init(url: URL?, isPrivate: Bool) {
        self.init(record: BrowserTabRecord(
            id: UUID(), url: url?.absoluteString, title: "New Tab",
            isPrivate: isPrivate, lastAccess: Date()
        ))
    }

    var record: BrowserTabRecord {
        BrowserTabRecord(id: id, url: url?.absoluteString, title: title,
                         isPrivate: isPrivate, lastAccess: lastAccess)
    }

    var engineView: UIView? { session?.engineView }

    @discardableResult
    func activate(settings: BrowserSettings, windowID: String? = nil) -> GeckoSession {
        lastAccess = Date()
        if let session { return session }
        let created = GeckoSession(settings: settings.geckoSettings, isPrivateMode: isPrivate)
        created.navigationDelegate = self
        created.progressDelegate = self
        created.contentDelegate = self
        created.permissionDelegate = permissionDelegate
        created.promptDelegate = promptDelegate
        created.open(windowId: windowID)
        session = created
        if windowID == nil, let url { created.load(url.absoluteString) }
        observer?.browserTabDidChange(self)
        return created
    }

    func suspend() {
        session?.close()
        session = nil
        progress = 0
        isLoading = false
    }

    func load(_ target: URL, settings: BrowserSettings) {
        url = target
        activate(settings: settings).load(target.absoluteString)
        observer?.browserTabDidChange(self)
    }

    func applySettings(_ settings: BrowserSettings) {
        session?.updateSettings(settings.geckoSettings)
    }

    func setActive(_ active: Bool) {
        session?.setActive(active)
        session?.setFocused(active)
    }

    func goBack() { session?.goBack() }
    func goForward() { session?.goForward() }
    func reload() { session?.reload() }
    func stop() { session?.stop() }

    func onLocationChange(session: GeckoSession, url: String?, permissions: [ContentPermission]) {
        self.url = url.flatMap(URL.init(string:))
        observer?.browserTabDidChange(self)
    }

    func onCanGoBack(session: GeckoSession, canGoBack: Bool) {
        self.canGoBack = canGoBack
        observer?.browserTabDidChange(self)
    }

    func onCanGoForward(session: GeckoSession, canGoForward: Bool) {
        self.canGoForward = canGoForward
        observer?.browserTabDidChange(self)
    }

    func onNewSession(session: GeckoSession, uri: String, windowId: String) async -> GeckoSession? {
        guard let target = URL(string: uri) else { return nil }
        return observer?.browserTab(self, requestedNewTab: target, windowID: windowId)
    }

    func onPageStart(session: GeckoSession, url: String) {
        isLoading = true
        progress = 4
        observer?.browserTabDidChange(self)
    }

    func onPageStop(session: GeckoSession, success: Bool) {
        isLoading = false
        progress = success ? 100 : progress
        observer?.browserTabDidChange(self)
    }

    func onProgressChange(session: GeckoSession, progress: Int) {
        self.progress = min(100, max(0, progress))
        observer?.browserTabDidChange(self)
    }

    func onTitleChange(session: GeckoSession, title: String) {
        self.title = title.isEmpty ? "New Tab" : title
        observer?.browserTabDidChange(self)
    }

    func onCloseRequest(session: GeckoSession) { observer?.browserTabDidRequestClose(self) }
    func onCrash(session: GeckoSession) { suspend(); observer?.browserTabDidChange(self) }
    func onKill(session: GeckoSession) { suspend(); observer?.browserTabDidChange(self) }

    func onExternalResponse(session: GeckoSession, response: ExternalResponseInfo) async -> Bool {
        await observer?.browserTab(self, requestedDownload: response) ?? false
    }

    func onExternalResponseProgress(session: GeckoSession, localFilePath: String, bytesReceived: Int64) -> Bool {
        observer?.browserTab(self, downloadAt: localFilePath, received: bytesReceived) ?? false
    }

    func onExternalResponseComplete(session: GeckoSession, localFilePath: String, succeeded: Bool) {
        observer?.browserTab(self, completedDownloadAt: localFilePath, succeeded: succeeded)
    }

    deinit { session?.close() }
}
