import UIKit
import UniformTypeIdentifiers

@MainActor
final class VulpraOpenInViewController: UIViewController {
    private var didFinish = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        loadSharedURL()
    }

    private func loadSharedURL() {
        guard let extensionContext else {
            return
        }

        let provider = extensionContext.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
            .first { itemProvider in
                itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
            }

        guard let provider else {
            finish(.failure(makeError(code: 1, description: "No shared web URL was provided")))
            return
        }

        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
            Task { @MainActor in
                guard let self else {
                    return
                }
                if let error {
                    self.finish(.failure(error))
                    return
                }
                guard
                    let sharedURL = item as? URL,
                    let scheme = sharedURL.scheme?.lowercased(),
                    scheme == "http" || scheme == "https"
                else {
                    self.finish(.failure(self.makeError(code: 2, description: "The shared item is not a web URL")))
                    return
                }
                self.openSharedURL(sharedURL)
            }
        }
    }

    private func openSharedURL(_ sharedURL: URL) {
        var components = URLComponents()
        components.scheme = "vulpra"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "url", value: sharedURL.absoluteString)
        ]

        guard let destination = components.url, let extensionContext else {
            finish(.failure(makeError(code: 3, description: "Unable to create the Vulpra URL")))
            return
        }

        extensionContext.open(destination) { [weak self] opened in
            Task { @MainActor in
                guard let self else {
                    return
                }
                if opened {
                    self.finish(.success(()))
                } else {
                    self.finish(.failure(self.makeError(code: 4, description: "Vulpra did not accept the shared URL")))
                }
            }
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard !didFinish else {
            return
        }
        didFinish = true

        guard let extensionContext else {
            return
        }
        switch result {
        case .success:
            extensionContext.completeRequest(returningItems: [], completionHandler: nil)
        case .failure(let error):
            extensionContext.cancelRequest(withError: error)
        }
    }

    private func makeError(code: Int, description: String) -> NSError {
        NSError(
            domain: "Vulpra.OpenIn",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}
