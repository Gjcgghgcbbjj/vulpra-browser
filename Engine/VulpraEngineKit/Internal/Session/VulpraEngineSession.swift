import Foundation
import os
import UIKit

@MainActor
public final class VulpraEngineSession: EngineSession {
    private static let logger = Logger(subsystem: "com.vulpra.browser.engine-kit", category: "session")
    public let id = EngineSessionID()
    public private(set) var configuration: EngineSessionConfiguration
    public weak var navigationObserver: (any EngineNavigationObserver)?
    public weak var progressObserver: (any EngineProgressObserver)?
    public weak var contentObserver: (any EngineContentObserver)?
    public weak var fullscreenObserver: (any EngineFullscreenObserver)?
    public weak var securityObserver: (any EngineSecurityObserver)?
    public weak var promptHandler: (any EnginePromptHandler)?
    public weak var permissionHandler: (any EnginePermissionHandler)?
    public weak var clipboardPermissionHandler: (any EngineClipboardPermissionHandler)?
    public weak var downloadHandler: (any EngineDownloadHandler)?

    private let runtime: VulpraEngineRuntime
    private var window: UnsafeMutableRawPointer?
    private var lifecycle = EngineSessionLifecycle()
    private var readinessObservation: UUID?
    private var requestedWindowID: String?
    private var pendingCommands: [(type: String, message: [String: Any])] = []
    private var pendingInitialLoadCommands: [(type: String, message: [String: Any])] = []
    private var awaitingInitialPageStop = false
    private var stoppedByUser = false
    private var navigationFailureReported = false
    private var navigation = EngineNavigationEvent(
        sessionID: EngineSessionID(), url: nil, title: "", canGoBack: false, canGoForward: false
    )

    public init(runtime: VulpraEngineRuntime, configuration: EngineSessionConfiguration) {
        self.runtime = runtime
        self.configuration = configuration
        navigation = EngineNavigationEvent(
            sessionID: id, url: nil, title: "", canGoBack: false, canGoForward: false
        )
    }

    public var state: EngineSessionState { lifecycle.state }
    public var isOpen: Bool { state == .open && window != nil }

    public func makeView() -> any EngineView { VulpraEngineView(session: self) }

    public var contentView: UIView? {
        guard let window, let pointer = engineABIWindowView(window) else { return nil }
        return Unmanaged<UIView>.fromOpaque(pointer).takeUnretainedValue()
    }

    public func open(windowID: String? = nil) {
        guard window == nil, lifecycle.beginOpen() else { return }
        requestedWindowID = windowID
        Self.logger.notice("Engine window requested")
        readinessObservation = runtime.observeReady { [weak self] result in
            guard let self else { return }
            self.readinessObservation = nil
            switch result {
            case .success: self.openNow()
            case .failure(let failure): self.failOpen(failure)
            }
        }
    }

    private func openNow() {
        guard window == nil, state == .opening else { return }
        guard let runtimeHandle = runtime.requiredHandle() else {
            failOpen(EngineFailure(
                code: "runtime-unavailable", message: "Engine runtime is unavailable", isRecoverable: true
            ))
            return
        }
        runtime.applyTrackingProtectionPrefs(configuration.trackingProtection)
        let identifier = (requestedWindowID ?? id.rawValue.uuidString.replacingOccurrences(of: "-", with: "")) as NSString
        let initialData = Self.initialData(configuration) as NSDictionary
        let owner = EngineABIContext(self)
        let context = Unmanaged.passUnretained(owner).toOpaque()
        window = withExtendedLifetime(identifier) {
            withExtendedLifetime(initialData) {
                withExtendedLifetime(owner) {
                    engineABIWindowOpen(
                        runtimeHandle, engineABIPointer(identifier), engineABIPointer(initialData),
                        configuration.isPrivate, context, vulpraSessionEventHandler
                    )
                }
            }
        }
        if window == nil {
            Self.logger.error("Engine window open failed")
            failOpen(EngineFailure(
                code: "window-open-failed", message: "Engine window could not be opened", isRecoverable: true
            ))
        } else {
            guard lifecycle.becomeOpen() else {
                let openedWindow = window
                window = nil
                if let openedWindow { engineABIWindowClose(openedWindow) }
                return
            }
            Self.logger.notice("Engine window opened")
            navigationObserver?.engineSessionDidOpen(id)
            if !pendingInitialLoadCommands.isEmpty {
                awaitingInitialPageStop = true
            }
            flushPendingCommands()
        }
    }

    public func close() {
        runtime.cancelReadyObservation(identifier: readinessObservation)
        readinessObservation = nil
        requestedWindowID = nil
        pendingCommands.removeAll()
        pendingInitialLoadCommands.removeAll()
        awaitingInitialPageStop = false
        guard lifecycle.beginClose() else { return }
        guard let window else { lifecycle.finishClose(); return }
        self.window = nil
        engineABIWindowClose(window)
        lifecycle.finishClose()
    }

    public func load(_ request: EngineNavigationRequest) {
        Self.logger.notice(
            "Engine load requested: \(request.url.absoluteString, privacy: .public), open: \(self.isOpen, privacy: .public)"
        )
        send("GeckoView:LoadUri", ["uri": request.url.absoluteString, "flags": 0])
    }
    public func goBack() { send("GeckoView:GoBack", ["userInteraction": true]) }
    public func goForward() { send("GeckoView:GoForward", ["userInteraction": true]) }
    public func reload() { send("GeckoView:Reload", ["flags": 0]) }
    public func stop() { stoppedByUser = true; send("GeckoView:Stop") }
    public func setActive(_ active: Bool) { send("GeckoView:SetActive", ["active": active]) }
    public func setFocused(_ focused: Bool) { send("GeckoView:SetFocused", ["focused": focused]) }
    public func exitFullscreen() { send("GeckoViewContent:ExitFullScreen") }

    public func update(configuration: EngineSessionConfiguration) {
        self.configuration = configuration
        send("GeckoView:UpdateSettings", Self.settings(configuration))
    }

    private func send(_ type: String, _ message: [String: Any] = [:]) {
        if window != nil {
            // A2: immediate dispatch path (window open before LoadUri).
            if type == "GeckoView:LoadUri" {
                Self.logger.notice("initial_load_deferred=false")
            }
            dispatch(type, message)
            return
        }

        guard state == .opening else {
            Self.logger.error("Engine command rejected while session is closed: \(type, privacy: .public)")
            return
        }
        if type == "GeckoView:LoadUri" {
            // A2: deferred path — LoadUri waits for the first PageStop of the
            // initial (about:blank) window before dispatch.
            Self.logger.notice("initial_load_deferred=true")
            pendingInitialLoadCommands.append((type, message))
            return
        }
        pendingCommands.append((type, message))
    }

    private func flushPendingCommands() {
        let commands = pendingCommands
        pendingCommands.removeAll()
        for command in commands {
            dispatch(command.type, command.message)
        }
    }

    private func failOpen(_ failure: EngineFailure) {
        readinessObservation = nil
        requestedWindowID = nil
        pendingCommands.removeAll()
        pendingInitialLoadCommands.removeAll()
        awaitingInitialPageStop = false
        lifecycle.fail(failure)
        Self.logger.error("Engine session failed: \(failure.code, privacy: .public)")
        progressObserver?.engineSession(id, didUpdate: .failed(sessionID: id, failure: failure))
    }

    private func dispatch(_ type: String, _ message: [String: Any]) {
        guard let window else { return }
        Self.logger.notice("Engine command dispatched: \(type, privacy: .public)")
        let name = type as NSString
        let payload = message as NSDictionary
        withExtendedLifetime(name) {
            withExtendedLifetime(payload) {
                engineABIWindowDispatch(window, engineABIPointer(name), engineABIPointer(payload))
            }
        }
    }

    func handle(type: String, message: Any?, callback: EngineABICallbackLease?) {
        let payload = message as? [String: Any] ?? [:]
        handleOnMain(type: type, payload: payload, callback: callback)
    }

    private func handleOnMain(type: String, payload: [String: Any], callback: EngineABICallbackLease?) {
        switch type {
        case "GeckoView:LocationChange":
            navigation = EngineNavigationEvent(
                sessionID: id, url: Self.url(payload["uri"]), title: navigation.title,
                canGoBack: payload["canGoBack"] as? Bool ?? false,
                canGoForward: payload["canGoForward"] as? Bool ?? false
            )
            if let url = navigation.url {
                Self.logger.notice("Engine location: \(url.absoluteString, privacy: .public)")
            }
            navigationObserver?.engineSession(id, didUpdate: navigation)
        case "GeckoView:PageTitleChanged":
            navigation = EngineNavigationEvent(
                sessionID: id, url: navigation.url, title: payload["title"] as? String ?? "",
                canGoBack: navigation.canGoBack, canGoForward: navigation.canGoForward
            )
            navigationObserver?.engineSession(id, didUpdate: navigation)
        case "GeckoView:PageStart":
            stoppedByUser = false
            navigationFailureReported = false
            progressObserver?.engineSession(id, didUpdate: .started(sessionID: id, url: Self.url(payload["uri"])))
        case "GeckoView:PageStop":
            let succeeded = payload["success"] as? Bool ?? false
            Self.logger.notice("Engine page completed: \(succeeded, privacy: .public)")
            if succeeded || stoppedByUser {
                progressObserver?.engineSession(id, didUpdate: .completed(sessionID: id, succeeded: succeeded))
            } else if !navigationFailureReported { reportNavigationFailure(payload) }
            stoppedByUser = false
            if awaitingInitialPageStop {
                awaitingInitialPageStop = false
                let initialLoads = pendingInitialLoadCommands
                pendingInitialLoadCommands.removeAll()
                for command in initialLoads { dispatch(command.type, command.message) }
            }
        case "GeckoView:ProgressChanged":
            let value = (payload["progress"] as? NSNumber)?.doubleValue ?? 0
            progressObserver?.engineSession(id, didUpdate: .changed(sessionID: id, fraction: max(0, min(1, value / 100))))
        case "GeckoView:DOMWindowClose": navigationObserver?.engineSessionDidRequestClose(id)
        case "GeckoView:ContentCrash": progressObserver?.engineSession(id, didTerminate: .processExited)
        case "GeckoView:ContentKill": progressObserver?.engineSession(id, didTerminate: .killed)
        case "GeckoView:OnLoadError":
            reportNavigationFailure(payload)
        case "GeckoView:OnNewSession":
            let accepted = Self.url(payload["uri"]).map {
                navigationObserver?.engineSession(id, requestedNewSessionFor: $0,
                                                  windowID: payload["newSessionId"] as? String ?? "") ?? false
            } ?? false
            resolve(callback, value: NSNumber(value: accepted))
            return
        case "GeckoView:ContextMenu":
            contentObserver?.engineSession(id, requestedContextMenu: EngineContextMenuElement(
                title: payload["title"] as? String,
                linkURL: Self.url(payload["linkUri"] ?? payload["linkURL"]),
                imageURL: Self.url(payload["srcUri"] ?? payload["imageURL"])
            ))
        case "GeckoView:Prompt": handlePrompt(payload, callback: callback); return
        case "GeckoView:ContentPermission", "GeckoView:MediaPermission":
            handlePermission(payload, callback: callback); return
        case "GeckoView:ExternalResponse": handleDownload(payload, callback: callback); return
        case "GeckoView:ExternalResponseProgress":
            let keep = downloadHandler?.engineSession(
                id, downloadAt: payload["localFilePath"] as? String ?? "",
                received: (payload["bytesReceived"] as? NSNumber)?.int64Value ?? 0
            ) ?? false
            resolve(callback, value: NSNumber(value: keep)); return
        case "GeckoView:ExternalResponseComplete":
            downloadHandler?.engineSession(
                id, completedDownloadAt: payload["localFilePath"] as? String ?? "",
                succeeded: payload["succeeded"] as? Bool ?? false
            )
        case "GeckoView:ClipboardPermissionRequest":
            handleClipboardPermission(payload, callback: callback); return
        case "GeckoView:DOMFullscreenEntered": fullscreenObserver?.engineSessionDidEnterFullscreen(id)
        case "GeckoView:DOMFullscreenExited": fullscreenObserver?.engineSessionDidExitFullscreen(id)
        case "GeckoView:SecurityChanged":
            if let security = Self.securityEvent(id, payload) {
                securityObserver?.engineSession(id, didUpdate: security)
            }
        default: break
        }
        resolve(callback, value: NSNull())
    }

    private func reportNavigationFailure(_ payload: [String: Any]) {
        navigationFailureReported = true
        if let failedURL = Self.url(payload["uri"]) {
            navigation = EngineNavigationEvent(
                sessionID: id, url: failedURL, title: navigation.title,
                canGoBack: navigation.canGoBack, canGoForward: navigation.canGoForward
            )
            navigationObserver?.engineSession(id, didUpdate: navigation)
        }
        let detail = payload["message"] ?? payload["error"] ?? payload["errorCode"]
        let message = detail.map { String(describing: $0) } ?? "The page could not be loaded"
        progressObserver?.engineSession(id, didUpdate: .failed(
            sessionID: id, failure: EngineFailure(code: "navigation-failed", message: message, isRecoverable: true)
        ))
    }
    private static func securityEvent(_ sessionID: EngineSessionID, _ payload: [String: Any]) -> EngineSecurityEvent? {
        guard let identity = payload["identity"] as? [String: Any] else { return nil }
        let mode = identity["mode"] as? [String: Any] ?? [:]
        return EngineSecurityEvent(
            sessionID: sessionID,
            origin: identity["origin"] as? String,
            isSecure: identity["secure"] as? Bool ?? false,
            host: identity["host"] as? String,
            identityMode: mode["identity"] as? String ?? "unknown",
            hasMixedDisplayContent: (mode["mixed_display"] as? NSNumber)?.boolValue ?? false,
            hasMixedActiveContent: (mode["mixed_active"] as? NSNumber)?.boolValue ?? false,
            certificate: identity["certificate"] as? String,
            hasSecurityException: identity["securityException"] as? Bool ?? false
        )
    }

    private func handlePrompt(_ payload: [String: Any], callback: EngineABICallbackLease?) {
        let value = payload["prompt"] as? [String: Any] ?? payload
        let type = (value["type"] as? String ?? value["promptType"] as? String ?? "").lowercased()
        let kind: EnginePromptKind = type == "share" ? .share :
            type.contains("auth") ? .authentication :
            type.contains("text") ? .text : type.contains("confirm") ? .confirm :
            type.contains("file") ? .file : type.contains("alert") ? .alert : .unknown
        let request = EnginePromptRequest(
            id: value["id"] as? String ?? UUID().uuidString, kind: kind,
            title: value["title"] as? String ?? "", message: value["message"] as? String ?? "",
            defaultValue: value["defaultValue"] as? String,
            text: value["text"] as? String, uri: Self.url(value["uri"])
        )
        guard let promptHandler else { resolve(callback, value: NSNull()); return }
        if kind == .share {
            // Gecko ShareDelegate.sys.mjs expects {response: 0|1|2}
            // (0 = success, 1 = failure, 2 = abort/dismiss).
            promptHandler.engineSession(id, handle: request) { response in
                let dictionary: NSDictionary = ["response": NSNumber(value: response?.accepted ?? false ? 0 : 2)]
                resolve(callback, value: dictionary)
            }
            return
        }
        promptHandler.engineSession(id, handle: request) { response in
            let dictionary: NSDictionary = [
                "allow": response?.accepted ?? false,
                "text": response?.text ?? NSNull(),
                "files": response?.files.map(\.path) ?? []
            ]
            resolve(callback, value: dictionary)
        }
    }

    private func handlePermission(_ payload: [String: Any], callback: EngineABICallbackLease?) {
        let raw = (payload["perm"] as? String ?? payload["type"] as? String ?? "").lowercased()
        let kind: EnginePermissionKind = raw.contains("camera") ? .camera :
            raw.contains("microphone") || raw.contains("audio") ? .microphone :
            raw.contains("geo") || raw.contains("location") ? .location :
            raw.contains("notification") ? .notifications : raw.contains("storage") ? .persistentStorage : .unknown
        let request = EnginePermissionRequest(
            origin: Self.url(payload["uri"]), kind: kind, isPrivate: payload["privateMode"] as? Bool ?? configuration.isPrivate
        )
        guard let permissionHandler else { resolve(callback, value: NSNumber(value: 0)); return }
        permissionHandler.engineSession(id, decide: request) { decision in
            resolve(callback, value: NSNumber(value: decision.rawValue))
        }
    }

    private func handleClipboardPermission(_ payload: [String: Any], callback: EngineABICallbackLease?) {
        let rawPoint = payload["screenPoint"] as? [String: Any] ?? [:]
        let point = EngineScreenPoint(
            x: (rawPoint["x"] as? NSNumber)?.doubleValue ?? 0,
            y: (rawPoint["y"] as? NSNumber)?.doubleValue ?? 0
        )
        // No handler: default to deny (resolves, never hangs) — A51 amendment.
        guard let clipboardPermissionHandler else { resolve(callback, value: NSNumber(value: false)); return }
        clipboardPermissionHandler.engineSession(id, requestedClipboardAccessAt: point) { allow in
            resolve(callback, value: NSNumber(value: allow))
        }
    }

    private func handleDownload(_ payload: [String: Any], callback: EngineABICallbackLease?) {
        let response = EngineDownloadResponse(
            sourceURL: Self.url(payload["uri"] ?? payload["url"]),
            suggestedFilename: payload["suggestedFilename"] as? String ?? payload["filename"] as? String,
            contentType: payload["contentType"] as? String,
            contentLength: (payload["contentLength"] as? NSNumber)?.int64Value ?? -1,
            localFilePath: payload["localFilePath"] as? String ?? ""
        )
        guard let downloadHandler else { resolve(callback, value: NSNumber(value: false)); return }
        downloadHandler.engineSession(id, accept: response) { accepted in
            resolve(callback, value: NSNumber(value: accepted))
        }
    }

    private static func url(_ value: Any?) -> URL? {
        (value as? String).flatMap(URL.init(string:))
    }

    private static func initialData(_ value: EngineSessionConfiguration) -> [String: Any] {
        ["settings": settings(value), "modules": [
            "GeckoViewContent": true, "GeckoViewNavigation": true,
            "GeckoViewPermission": true, "GeckoViewProgress": true,
            "GeckoViewContentBlocking": true
        ]]
    }

    private static func settings(_ value: EngineSessionConfiguration) -> [String: Any] {
        ["chromeUri": NSNull(), "screenId": 0, "useTrackingProtection": value.trackingProtection != .off,
         "userAgentMode": value.userAgentMode == .desktop ? 1 : 0, "userAgentOverride": NSNull(),
         "viewportMode": value.userAgentMode == .desktop ? 1 : 0, "pageZoom": value.pageZoom,
         "displayMode": 0, "suspendMediaWhenInactive": false, "allowJavascript": true,
         "fullAccessibilityTree": false, "isExtensionPopup": false,
         "sessionContextId": NSNull(), "unsafeSessionContextId": NSNull()]
    }

}

private let vulpraSessionEventHandler: EngineABIEventHandler = { context, type, message, callback in
    let lease = takeCallback(callback)
    guard let context else { lease?.cancel("session unavailable"); return }
    let owner = Unmanaged<EngineABIContext<VulpraEngineSession>>.fromOpaque(context).takeUnretainedValue()
    let session = owner.value
    let eventType = bridgeString(type)
    let eventMessage = bridgeObject(message)
    DispatchQueue.main.async {
        session.handle(type: eventType, message: eventMessage, callback: lease)
    }
}

@MainActor
private final class VulpraEngineView: EngineView {
    weak var session: VulpraEngineSession?
    init(session: VulpraEngineSession) { self.session = session }
    var contentView: UIView? { session?.contentView }
    func setVisible(_ visible: Bool) { contentView?.isHidden = !visible; session?.setActive(visible) }
    func setFocused(_ focused: Bool) { session?.setFocused(focused) }
}
