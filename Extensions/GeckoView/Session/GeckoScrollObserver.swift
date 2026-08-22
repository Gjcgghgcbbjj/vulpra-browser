import Foundation

/// Bridges the engine's per-session scroll telemetry
/// (`GeckoView:ScrollChanged {scrollX, scrollY}` from ScrollDelegate) to a
/// Swift callback, enabling Safari-style scroll-aware chrome without any
/// overlay on the page.
public final class GeckoScrollObserver: GeckoEventListenerInternal {
    private weak var dispatcher: GeckoEventDispatcherWrapper?
    /// Called on the main thread with the latest vertical scroll offset.
    public var onScrollY: ((CGFloat) -> Void)?

    public init() {}

    /// Idempotent per dispatcher; attaching the same observer to several
    /// sessions simply widens the source (handlers should filter).
    public func attach(to session: GeckoSession) {
        let dispatcher = session.dispatcher
        self.dispatcher = dispatcher
        dispatcher.addListener(type: "GeckoView:ScrollChanged", listener: self)
    }

    func handleMessage(type: String, message: [String: Any?]?) async throws -> Any? {
        guard type == "GeckoView:ScrollChanged" else { return nil }
        let raw = message?["scrollY"]
        let scrollY: CGFloat?
        if let value = raw as? CGFloat {
            scrollY = value
        } else if let number = raw as? NSNumber {
            scrollY = CGFloat(number.doubleValue)
        } else {
            scrollY = nil
        }
        guard let scrollY else { return nil }
        DispatchQueue.main.async { [weak self] in
            self?.onScrollY?(scrollY)
        }
        return nil
    }
}
