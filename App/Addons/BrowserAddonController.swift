import GeckoView
import UIKit

final class BrowserAddonController: AddonEmbedderDelegate {
    weak var presenter: UIViewController?
    weak var tabManager: TabManager?
    var onOpenURL: ((URL) -> Void)?

    init() {
        // Defer WebExtension:List until Gecko AutoJSAPI can Init.
        GeckoEngineGate.whenReady {
            AddonRuntime.shared.delegate = self
        }
    }

    func addonController(_ controller: AddonRuntime, didUpdate addon: Addon) {
        NotificationCenter.default.post(name: .browserAddonsDidChange, object: controller)
    }

    @MainActor
    func addonController(_ controller: AddonRuntime,
                         promptFor prompt: AddonPermissionPrompt) async -> AddonPermissionPromptResponse {
        guard let presenter else { return .deny }
        let name = prompt.addon.metaData.name ?? "Extension"
        let details = (prompt.permissions + prompt.origins + prompt.dataCollectionPermissions).joined(separator: "\n")
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: "Allow \(name)?", message: details, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in continuation.resume(returning: .deny) })
            alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in
                continuation.resume(returning: AddonPermissionPromptResponse(allow: true))
            })
            presenter.present(alert, animated: true)
        }
    }

    func addonController(_ controller: AddonRuntime, didRequestOpenPopup popupURL: String,
                         for addon: Addon, action: AddonAction, session: GeckoSession?) {
        if let url = URL(string: popupURL) { DispatchQueue.main.async { self.onOpenURL?(url) } }
    }

    func addonController(_ controller: AddonRuntime, didRequestOpenOptionsPageFor addon: Addon) {
        if let value = addon.metaData.optionsPageURL, let url = URL(string: value) {
            DispatchQueue.main.async { self.onOpenURL?(url) }
        }
    }

    func addonController(_ controller: AddonRuntime, createNewTabFor addon: Addon,
                         details: AddonCreateTabDetails, newSessionID: String) -> Bool {
        guard let manager = tabManager else { return false }
        let tab = manager.newTab(url: details.url.flatMap(URL.init(string:)), privateMode: false,
                                 select: details.active ?? true, windowID: newSessionID)
        return tab.session != nil
    }

    func addonController(_ controller: AddonRuntime, updateTab session: GeckoSession,
                         for addon: Addon, details: AddonUpdateTabDetails) -> AllowOrDeny {
        guard let tab = tabManager?.tabs.first(where: { $0.session === session }) else { return .deny }
        if let value = details.url, let url = URL(string: value) { tab.load(url, settings: BrowserSettingsStore.shared.value) }
        if details.active == true { tabManager?.select(tab) }
        return .allow
    }

    func addonController(_ controller: AddonRuntime, closeTab session: GeckoSession,
                         for addon: Addon) -> AllowOrDeny {
        guard let tab = tabManager?.tabs.first(where: { $0.session === session }) else { return .deny }
        tabManager?.close(tab)
        return .allow
    }
}

extension Notification.Name {
    static let browserAddonsDidChange = Notification.Name("VulpraBrowserAddonsDidChange")
}
