import GeckoView
import UniformTypeIdentifiers
import UIKit

final class BrowserPromptController: NSObject, PromptDelegate, UIDocumentPickerDelegate {
    weak var presenter: UIViewController?
    private var fileContinuation: CheckedContinuation<PromptResponse?, Never>?

    func onPrompt(session: GeckoSession, request: PromptRequest) async -> PromptResponse? {
        switch request {
        case .alert(let value):
            _ = await alert(title: value.title, message: value.message, fields: [], buttons: ["OK"])
            return nil
        case .button(let value):
            let labels = value.customButtonTitles.isEmpty ? value.buttonTitles : value.customButtonTitles
            let index = await alert(title: value.title, message: value.message, fields: [], buttons: labels.isEmpty ? ["OK"] : labels).index
            return .button(index)
        case .text(let value):
            let result = await alert(title: value.title, message: value.message, fields: [(value.value, false)], buttons: ["Cancel", "OK"])
            return result.index == 0 ? nil : .text(result.values.first ?? "")
        case .auth(let value):
            let result = await alert(title: value.title.isEmpty ? "Sign In" : value.title, message: value.message,
                                     fields: [(value.username, false), (value.password, true)], buttons: ["Cancel", "Sign In"])
            return result.index == 0 ? nil : .auth(username: result.values.first ?? "", password: result.values.last ?? "")
        case .folderUpload(let value):
            let result = await alert(title: "Upload Folder?", message: value.directoryName,
                                     fields: [], buttons: ["Cancel", "Upload"])
            return .folderUpload(allowed: result.index == 1)
        case .choice(let value):
            return await choose(value)
        case .file:
            return await pickFiles()
        case .color(let value):
            return .color(value.value)
        case .dateTime(let value):
            return value.value.isEmpty ? nil : .dateTime(value.value)
        }
    }

    func onPromptUpdate(session: GeckoSession, request: PromptRequest) {}
    func onPromptDismiss(session: GeckoSession, promptId: String) {}

    private func alert(title: String, message: String, fields: [(String, Bool)], buttons: [String]) async -> (index: Int, values: [String]) {
        guard let presenter else { return (0, []) }
        return await withCheckedContinuation { continuation in
            let controller = UIAlertController(title: title.isEmpty ? nil : title,
                                               message: message.isEmpty ? nil : message, preferredStyle: .alert)
            fields.forEach { value, secure in
                controller.addTextField { $0.text = value; $0.isSecureTextEntry = secure }
            }
            buttons.enumerated().forEach { index, title in
                controller.addAction(UIAlertAction(title: title, style: index == 0 && buttons.count > 1 ? .cancel : .default) { _ in
                    continuation.resume(returning: (index, controller.textFields?.map { $0.text ?? "" } ?? []))
                })
            }
            presenter.present(controller, animated: true)
        }
    }

    private func choose(_ request: SelectPromptRequest) async -> PromptResponse? {
        guard let presenter else { return nil }
        let choices = request.choices.filter { !$0.disabled && !$0.separator }
        return await withCheckedContinuation { continuation in
            let sheet = UIAlertController(title: "Select", message: nil, preferredStyle: .actionSheet)
            choices.forEach { choice in
                sheet.addAction(UIAlertAction(title: choice.label, style: .default) { _ in
                    continuation.resume(returning: .choices([choice.id]))
                })
            }
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in continuation.resume(returning: nil) })
            sheet.popoverPresentationController?.sourceView = presenter.view
            presenter.present(sheet, animated: true)
        }
    }

    private func pickFiles() async -> PromptResponse? {
        guard let presenter, fileContinuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            fileContinuation = continuation
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
            picker.allowsMultipleSelection = true
            picker.delegate = self
            presenter.present(picker, animated: true)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        fileContinuation?.resume(returning: .files(["files": urls.map(\.path)]))
        fileContinuation = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        fileContinuation?.resume(returning: nil)
        fileContinuation = nil
    }
}
