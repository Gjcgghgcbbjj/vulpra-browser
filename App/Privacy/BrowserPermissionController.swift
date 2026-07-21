import GeckoView
import UIKit

final class BrowserPermissionController: PermissionEmbedderDelegate {
    weak var presenter: UIViewController?

    @MainActor
    func permissionDelegate(decideContentPermission permission: ContentPermission,
                            session: GeckoSession) async -> ContentPermission.Value {
        let host = ContentPermission.permissionHost(from: permission.uri)
        let key = permission.permission?.rawValue ?? "site-data"
        if !permission.privateMode, let saved = SitePermissionStore.shared.decision(host: host, permission: key) {
            return saved == .allow ? .allow : .deny
        }
        let allowed = await ask(title: host, message: "Allow access to \(key.replacingOccurrences(of: "-", with: " "))?")
        if !permission.privateMode {
            SitePermissionStore.shared.set(host: host, permission: key, decision: allowed ? .allow : .deny)
        }
        return allowed ? .allow : .deny
    }

    @MainActor
    func permissionDelegate(decideMediaPermission request: MediaPermissionRequest,
                            session: GeckoSession) async -> Bool {
        var kinds: [String] = []
        if request.videoRequested { kinds.append("camera") }
        if request.audioRequested { kinds.append("microphone") }
        return await ask(title: request.host, message: "Allow access to \(kinds.joined(separator: " and "))?")
    }

    @MainActor
    private func ask(title: String, message: String) async -> Bool {
        guard let presenter else { return false }
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel) { _ in continuation.resume(returning: false) })
            alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in continuation.resume(returning: true) })
            presenter.present(alert, animated: true)
        }
    }
}
