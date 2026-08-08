import Foundation
import UIKit
import VulpraEngineKit

struct BrowserTabRecord: Codable, Equatable {
    let id: UUID
    var url: String?
    var title: String
    var isPrivate: Bool
    var lastAccess: Date
}

@MainActor
protocol BrowserTabObserver: AnyObject {
    func browserTabPresentationDidChange(_ tab: BrowserTab)
    func browserTabPersistableStateDidChange(_ tab: BrowserTab)
    func browserTabContentDidChange(_ tab: BrowserTab)
    func browserTabDidRequestClose(_ tab: BrowserTab)
    func browserTab(_ tab: BrowserTab, requestedNewTab url: URL, windowID: String) -> Bool
    func browserTab(_ tab: BrowserTab, requestedDownload response: EngineDownloadResponse,
                    completion: @escaping (Bool) -> Void)
    func browserTab(_ tab: BrowserTab, downloadAt path: String, received bytes: Int64) -> Bool
    func browserTab(_ tab: BrowserTab, completedDownloadAt path: String, succeeded: Bool)
    func browserTab(_ tab: BrowserTab, requestedContextMenu element: EngineContextMenuElement)
}

@MainActor
final class BrowserTab: EngineNavigationObserver, EngineProgressObserver,
    EngineContentObserver, EngineDownloadHandler {
    let id: UUID
    let isPrivate: Bool
    weak var observer: BrowserTabObserver?
    private let runtime: any EngineRuntime
    private(set) var session: (any EngineSession)?
    private var engineSurface: (any EngineView)?
    private(set) var url: URL?
    private(set) var title: String
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var progress = 0
    private(set) var isLoading = false
    private(set) var lastFailure: EngineFailure?
    private(set) var httpFallbackURL: URL?
    private(set) var lastAccess: Date
    private(set) var thumbnail: UIImage?
    weak var permissionHandler: (any EnginePermissionHandler)?
    weak var clipboardPermissionHandler: (any EngineClipboardPermissionHandler)?
    weak var promptHandler: (any EnginePromptHandler)?

    init(record: BrowserTabRecord, runtime: any EngineRuntime) {
        self.runtime = runtime
        id = record.id
        isPrivate = record.isPrivate
        url = record.url.flatMap(URL.init(string:))
        title = record.title
        lastAccess = record.lastAccess
    }

    convenience init(url: URL?, isPrivate: Bool, runtime: any EngineRuntime) {
        self.init(record: BrowserTabRecord(
            id: UUID(), url: url?.absoluteString, title: "New Tab",
            isPrivate: isPrivate, lastAccess: Date()
        ), runtime: runtime)
    }

    var record: BrowserTabRecord {
        BrowserTabRecord(id: id, url: url?.absoluteString, title: title,
                         isPrivate: isPrivate, lastAccess: lastAccess)
    }

    var displayTitle: String {
        url == nil && title == "New Tab" ? VulpraL10n.text("tab.new") : title
    }

    var engineView: UIView? { engineSurface?.contentView }

    @discardableResult
    func activate(settings: BrowserSettings, windowID: String? = nil) -> any EngineSession {
        lastAccess = Date()
        if let session {
            if case .failed = session.state {
                lastFailure = nil
                session.open(windowID: windowID)
                if windowID == nil, let url {
                    session.load(EngineNavigationRequest(url: url, userInitiated: false))
                }
            }
            return session
        }
        let created = runtime.makeSession(configuration: settings.engineConfiguration(isPrivate: isPrivate))
        created.navigationObserver = self
        created.progressObserver = self
        created.contentObserver = self
        created.permissionHandler = permissionHandler
        created.clipboardPermissionHandler = clipboardPermissionHandler
        created.promptHandler = promptHandler
        created.downloadHandler = self
        session = created
        engineSurface = created.makeView()
        created.open(windowID: windowID)
        if windowID == nil, let url {
            created.load(EngineNavigationRequest(url: url, userInitiated: false))
        }
        return created
    }

    @MainActor
    func captureThumbnail(maximumSize: CGSize = CGSize(width: 360, height: 480)) {
        guard !isPrivate, let view = engineView, view.bounds.width > 0, view.bounds.height > 0 else { return }
        let scale = min(maximumSize.width / view.bounds.width, maximumSize.height / view.bounds.height, 1)
        let size = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        thumbnail = renderer.image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
    }

    var hasLiveSession: Bool { session != nil && engineSurface != nil }

    func releaseThumbnail() { thumbnail = nil }

    func suspend() {
        session?.close(); session = nil; engineSurface = nil; progress = 0; isLoading = false
    }

    func retry(settings: BrowserSettings) {
        lastFailure = nil
        if let url { load(url, settings: settings, httpFallbackURL: httpFallbackURL) }
        else { _ = activate(settings: settings) }
    }

    func load(_ target: URL, settings: BrowserSettings, httpFallbackURL: URL? = nil) {
        url = target
        lastFailure = nil
        self.httpFallbackURL = httpFallbackURL
        if let session, case .failed = session.state {
            _ = activate(settings: settings)
        } else if let session {
            session.load(EngineNavigationRequest(url: target))
        } else {
            activate(settings: settings)
        }
        observer?.browserTabPersistableStateDidChange(self)
    }

    func loadHTTPFallback(settings: BrowserSettings) {
        guard let fallback = httpFallbackURL else { return }
        load(fallback, settings: settings, httpFallbackURL: nil)
    }

    func applySettings(_ settings: BrowserSettings) {
        session?.update(configuration: settings.engineConfiguration(isPrivate: isPrivate))
    }

    func setActive(_ active: Bool) { session?.setActive(active); session?.setFocused(active) }
    func goBack() { session?.goBack() }
    func goForward() { session?.goForward() }
    func reload() { session?.reload() }
    func stop() { session?.stop() }

    func engineSessionDidOpen(_ id: EngineSessionID) {
        lastFailure = nil
        observer?.browserTabContentDidChange(self)
    }

    func engineSession(_ id: EngineSessionID, didUpdate event: EngineNavigationEvent) {
        url = event.url
        title = event.title.isEmpty ? title : event.title
        canGoBack = event.canGoBack
        canGoForward = event.canGoForward
        observer?.browserTabPersistableStateDidChange(self)
    }

    func engineSessionDidRequestClose(_ id: EngineSessionID) { observer?.browserTabDidRequestClose(self) }

    func engineSession(_ id: EngineSessionID, requestedNewSessionFor url: URL, windowID: String) -> Bool {
        observer?.browserTab(self, requestedNewTab: url, windowID: windowID) ?? false
    }

    func engineSession(_ id: EngineSessionID, didUpdate event: EngineProgressEvent) {
        switch event {
        case .started:
            lastFailure = nil; isLoading = true; progress = 4
        case .changed(_, let fraction):
            progress = min(100, max(0, Int(fraction * 100)))
        case .completed(_, let succeeded):
            isLoading = false
            if succeeded { progress = 100; httpFallbackURL = nil }
        case .failed(_, let failure):
            isLoading = false; lastFailure = failure
        }
        switch event {
        case .failed: observer?.browserTabContentDidChange(self)
        default: observer?.browserTabPresentationDidChange(self)
        }
    }

    func engineSession(_ id: EngineSessionID, didTerminate reason: EngineTerminationReason) {
        suspend(); observer?.browserTabContentDidChange(self)
    }

    func engineSession(_ id: EngineSessionID, requestedContextMenu element: EngineContextMenuElement) {
        observer?.browserTab(self, requestedContextMenu: element)
    }

    func engineSession(_ id: EngineSessionID, accept response: EngineDownloadResponse,
                       completion: @escaping (Bool) -> Void) {
        observer?.browserTab(self, requestedDownload: response, completion: completion)
    }

    func engineSession(_ id: EngineSessionID, downloadAt path: String, received bytes: Int64) -> Bool {
        observer?.browserTab(self, downloadAt: path, received: bytes) ?? false
    }

    func engineSession(_ id: EngineSessionID, completedDownloadAt path: String, succeeded: Bool) {
        observer?.browserTab(self, completedDownloadAt: path, succeeded: succeeded)
    }

}
