import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var browser: BrowserViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let initialRoute = RuntimeURLRouter.resolve(connectionOptions.urlContexts.first?.url)

        // State restoration: if the system is reconnecting an existing session,
        // restore the saved tab URLs from the NSUserActivity.
        var restoredURLs: [URL] = []
        if let activity = connectionOptions.userActivities.first {
            restoredURLs = Self.urls(from: activity)
        } else if let activity = session.stateRestorationActivity {
            restoredURLs = Self.urls(from: activity)
        }

        VulpraAppearance.applyGlobal()
        let initialWebURL: URL?
        if case .web(let url) = initialRoute {
            initialWebURL = url
        } else {
            initialWebURL = nil
        }
        let browser = BrowserViewController(initialURL: initialWebURL)
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        window.tintColor = VulpraAppearance.accent
        window.rootViewController = browser
        self.browser = browser
        self.window = window
        window.makeKeyAndVisible()

        // Restore tabs that were open before the app was killed.
        if initialWebURL == nil && !restoredURLs.isEmpty {
            browser.restoreTabs(urls: restoredURLs)
        }

        // Non-web routes (settings/tabs/…) need a loaded presentation context,
        // so they are handled on the next runloop tick after makeKeyAndVisible.
        if let route = initialRoute, !isWebRoute(route) {
            DispatchQueue.main.async { [weak browser] in
                browser?.handle(route)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let route = RuntimeURLRouter.resolve(URLContexts.first?.url) else { return }
        browser?.handle(route)
    }

    private func isWebRoute(_ route: InternalRoute) -> Bool {
        if case .web = route { return true }
        return false
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        browser?.setActive(true)
        EngineDiagnostics.run()
    }
    func sceneWillResignActive(_ scene: UIScene) { browser?.setActive(false) }
    func sceneDidEnterBackground(_ scene: UIScene) { browser?.setActive(false) }
    func sceneDidDisconnect(_ scene: UIScene) { browser?.closePrivateTabs() }

    // MARK: - State Restoration

    /// Save the current tab URLs into the scene's user activity so the system
    /// can restore them after a kill/relaunch.
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        guard let browser else { return nil }
        let activity = NSUserActivity(activityType: "com.vulpra.browser.restoration")
        let urls = browser.openTabURLs
        if !urls.isEmpty {
            activity.title = "\(urls.count) tabs"
            activity.userInfo = ["tabURLs": urls.map { $0.absoluteString }]
        }
        return activity
    }

    private static func urls(from activity: NSUserActivity) -> [URL] {
        guard let strings = activity.userInfo?["tabURLs"] as? [String] else { return [] }
        return strings.compactMap(URL.init(string:))
    }
}
