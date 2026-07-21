import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var runtimeShell: RuntimeShellViewController?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let initialURL = RuntimeURLRouter.resolve(connectionOptions.urlContexts.first?.url)
        let runtimeShell = RuntimeShellViewController(initialURL: initialURL)
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        window.rootViewController = runtimeShell

        self.runtimeShell = runtimeShell
        self.window = window
        window.makeKeyAndVisible()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard
            let url = RuntimeURLRouter.resolve(URLContexts.first?.url),
            let runtimeShell
        else {
            return
        }
        runtimeShell.open(url)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        runtimeShell?.setActive(true)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        runtimeShell?.setActive(false)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        runtimeShell?.setActive(false)
    }
}
