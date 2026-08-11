import os
import UIKit
import VulpraEngineKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private let logger = Logger(subsystem: "com.vulpra.browser", category: "build")
    var window: UIWindow?
    private var browser: BrowserViewController?
#if DEBUG
    private var gateDispatchServer: GateDispatchServer?
#endif

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        logger.notice("Client build fingerprint: \(VulpraBuildIdentity.uiFingerprint, privacy: .public)")
        var initialURL = RuntimeURLRouter.resolve(connectionOptions.urlContexts.first?.url)
#if DEBUG
        if initialURL == nil,
           let value = ProcessInfo.processInfo.environment["VULPRA_SMOKE_URL"],
           let candidate = URL(string: value) {
            initialURL = RuntimeURLRouter.resolve(candidate)
        }
#endif
        VulpraAppearance.applyGlobal()
        let browser = BrowserViewController(runtime: VulpraEngine.runtime, initialURL: initialURL)
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        window.tintColor = VulpraAppearance.accent
        window.rootViewController = browser
        self.browser = browser
        MemoryPressureRouter.attach(runtime: VulpraEngine.runtime, controller: browser)
        self.window = window
        window.makeKeyAndVisible()
#if DEBUG
        if let port = ProcessInfo.processInfo.environment["VULPRA_GATE_DISPATCH_PORT"],
           let server = GateDispatchServer(portText: port, onOpen: { [weak self] url in
               // Mirror scene openURLContexts: normalize the deep link back to the
               // target web URL before handing it to the browser/engine.
               guard let resolved = RuntimeURLRouter.resolve(url) else { return }
               self?.browser?.open(resolved)
           }, onTabSwitchDuringLoad: { [weak self] url in
               self?.browser?.runTabSwitchDuringLoadScenario(url: url)
           }, onScrollPerformance: { [weak self] url, seconds in
               self?.browser?.runScrollPerformanceScenario(url: url, seconds: seconds)
           }) {
            gateDispatchServer = server
            server.start()
        }
#endif
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = RuntimeURLRouter.resolve(URLContexts.first?.url) else { return }
        browser?.open(url)
    }

    func sceneDidBecomeActive(_ scene: UIScene) { browser?.setActive(true) }
    func sceneWillResignActive(_ scene: UIScene) { browser?.setActive(false) }
    func sceneDidEnterBackground(_ scene: UIScene) { browser?.setActive(false); browser?.applyMemoryPressure(.light) }
    func sceneDidDisconnect(_ scene: UIScene) {
        browser?.shutdown()
#if DEBUG
        gateDispatchServer?.stop()
        gateDispatchServer = nil
#endif
        browser = nil
        window = nil
    }
}
