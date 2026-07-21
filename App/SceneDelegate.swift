import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var browser: BrowserViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let initialURL = RuntimeURLRouter.resolve(connectionOptions.urlContexts.first?.url)
        let browser = BrowserViewController(initialURL: initialURL)
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        window.rootViewController = browser
        self.browser = browser
        self.window = window
        window.makeKeyAndVisible()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = RuntimeURLRouter.resolve(URLContexts.first?.url) else { return }
        browser?.open(url)
    }

    func sceneDidBecomeActive(_ scene: UIScene) { browser?.setActive(true) }
    func sceneWillResignActive(_ scene: UIScene) { browser?.setActive(false) }
    func sceneDidEnterBackground(_ scene: UIScene) { browser?.setActive(false) }
}
