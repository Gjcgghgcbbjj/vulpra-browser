import UniformTypeIdentifiers
import UIKit
import VulpraEngineKit

final class BrowserPromptController: NSObject, EnginePromptHandler, UIDocumentPickerDelegate {
    weak var presenter: UIViewController?
    private var fileCompletion: ((EnginePromptResponse?) -> Void)?
    private var shareCompletion: ((EnginePromptResponse?) -> Void)?
    private var sharePresentationDelegate: ShareDismissalDelegate?

    func engineSession(_ id: EngineSessionID, handle prompt: EnginePromptRequest,
                       completion: @escaping (EnginePromptResponse?) -> Void) {
        guard let presenter else { completion(nil); return }
        if prompt.kind == .share {
            guard shareCompletion == nil else { completion(nil); return }
            shareCompletion = completion
            var items: [Any] = []
            if let uri = prompt.uri { items.append(uri) }
            if let text = prompt.text, !text.isEmpty { items.append(text) }
            if let title = prompt.title.isEmpty ? nil : prompt.title { items.append(title) }
            guard !items.isEmpty else {
                shareCompletion = nil
                completion(EnginePromptResponse(accepted: false))
                return
            }
            let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
            sheet.completionWithItemsHandler = { [weak self] _, completed, _, _ in
                guard let self else { return }
                let response = EnginePromptResponse(accepted: completed)
                self.shareCompletion?(response)
                self.shareCompletion = nil
            }
            sharePresentationDelegate = ShareDismissalDelegate { [weak self] in
                guard let self else { return }
                self.shareCompletion?(EnginePromptResponse(accepted: false))
                self.shareCompletion = nil
            }
            sheet.presentationController?.delegate = sharePresentationDelegate
            presenter.present(sheet, animated: true)
            return
        }
        if prompt.kind == .file {
            guard fileCompletion == nil else { completion(nil); return }
            fileCompletion = completion
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
            picker.allowsMultipleSelection = true; picker.delegate = self
            presenter.present(picker, animated: true)
            return
        }

        let alert = UIAlertController(
            title: prompt.title.isEmpty ? nil : prompt.title,
            message: prompt.message.isEmpty ? nil : prompt.message,
            preferredStyle: .alert
        )
        if prompt.kind == .text || prompt.kind == .authentication {
            alert.addTextField { $0.text = prompt.defaultValue }
        }
        if prompt.kind == .authentication {
            alert.addTextField { $0.isSecureTextEntry = true }
        }
        if prompt.kind != .alert {
            alert.addAction(UIAlertAction(title: VulpraL10n.text("common.cancel"), style: .cancel) { _ in
                completion(EnginePromptResponse(accepted: false))
            })
        }
        let acceptTitle = VulpraL10n.text(prompt.kind == .alert ? "common.ok" : "common.continue")
        alert.addAction(UIAlertAction(title: acceptTitle, style: .default) { _ in
            completion(EnginePromptResponse(accepted: true, text: alert.textFields?.first?.text))
        })
        presenter.present(alert, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        fileCompletion?(EnginePromptResponse(accepted: true, files: urls)); fileCompletion = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        fileCompletion?(nil); fileCompletion = nil
    }
}

/// Reports swipe-down dismissal of the share sheet as an abort, matching
/// Gecko ShareDelegate's ABORT=2 response.
private final class ShareDismissalDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}
