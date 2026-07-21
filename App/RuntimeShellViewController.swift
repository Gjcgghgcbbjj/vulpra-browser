import GeckoView
import os
import UIKit

final class RuntimeShellViewController: UIViewController {
    private let logger = Logger(subsystem: "com.vulpra.browser", category: "runtime-shell")
    private let session: GeckoSession
    private let smokeURL = URL(string: "https://example.com/")!
    private var pendingURL: URL?
    private var isSessionOpen = false
    private var isSessionActive = false

    init(initialURL: URL? = nil) {
        session = GeckoSession()
        pendingURL = initialURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        openSessionIfNeeded()
    }

    func open(_ url: URL) {
        pendingURL = url
        guard isSessionOpen else {
            return
        }
        session.load(url.absoluteString)
    }

    func setActive(_ active: Bool) {
        isSessionActive = active
        guard isSessionOpen else {
            return
        }
        session.setActive(active)
        session.setFocused(active)
    }

    private func openSessionIfNeeded() {
        guard !isSessionOpen else {
            return
        }

        session.open()
        isSessionOpen = true

        guard let engineView = session.engineView else {
            logger.error("Gecko engine view unavailable after session open")
            showEngineFailure()
            return
        }

        engineView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(engineView)
        NSLayoutConstraint.activate([
            engineView.topAnchor.constraint(equalTo: view.topAnchor),
            engineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            engineView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            engineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let url = pendingURL ?? smokeURL
        session.load(url.absoluteString)
        session.setActive(isSessionActive)
        session.setFocused(isSessionActive)
    }

    private func showEngineFailure() {
        let label = UILabel()
        label.text = "Gecko engine view unavailable"
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    deinit {
        session.close()
    }
}
