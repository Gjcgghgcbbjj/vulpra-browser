import UIKit
import VulpraEngineKit

final class BrowserPermissionController: EnginePermissionHandler {
    weak var presenter: UIViewController?

    func engineSession(_ id: EngineSessionID, decide request: EnginePermissionRequest,
                       completion: @escaping (EnginePermissionDecision) -> Void) {
        let storageHost = request.origin?.host ?? "This site"
        let displayHost = request.origin?.host ?? VulpraL10n.text("permission.this_site")
        let key = request.kind.rawValue
        if !request.isPrivate, let saved = SitePermissionStore.shared.decision(host: storageHost, permission: key) {
            completion(saved == .allow ? .allow : .deny); return
        }
        guard let presenter else { completion(.deny); return }
        let alert = UIAlertController(
            title: displayHost,
            message: VulpraL10n.format("permission.request", displayHost, request.kind.localizedTitle),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: VulpraL10n.text("permission.dont_allow"), style: .cancel) { _ in
            if !request.isPrivate { SitePermissionStore.shared.set(host: storageHost, permission: key, decision: .deny) }
            completion(.deny)
        })
        alert.addAction(UIAlertAction(title: VulpraL10n.text("permission.allow"), style: .default) { _ in
            if !request.isPrivate { SitePermissionStore.shared.set(host: storageHost, permission: key, decision: .allow) }
            completion(.allow)
        })
        presenter.present(alert, animated: true)
    }
}

extension BrowserPermissionController: EngineClipboardPermissionHandler {
    func engineSession(_ id: EngineSessionID, requestedClipboardAccessAt point: EngineScreenPoint,
                       completion: @escaping (Bool) -> Void) {
        guard let presenter else { completion(false); return }
        let alert = UIAlertController(
            title: VulpraL10n.text("permission.this_site"),
            message: VulpraL10n.text("permission.clipboard_paste"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: VulpraL10n.text("permission.dont_allow"), style: .cancel) { _ in
            completion(false)
        })
        alert.addAction(UIAlertAction(title: VulpraL10n.text("permission.allow"), style: .default) { _ in
            completion(true)
        })
        presenter.present(alert, animated: true)
    }
}
