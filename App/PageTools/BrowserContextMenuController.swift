import GeckoView
import Photos
import UIKit

final class BrowserContextMenuController {
    var onOpenURL: ((URL) -> Void)?

    func present(element: ContextElement, from presenter: UIViewController, sourceView: UIView) {
        let menu = UIAlertController(title: element.title ?? element.altText, message: nil, preferredStyle: .actionSheet)
        if let value = element.linkUri, let url = URL(string: value) {
            menu.addAction(UIAlertAction(title: "Open Link", style: .default) { _ in self.onOpenURL?(url) })
            menu.addAction(UIAlertAction(title: "Copy Link", style: .default) { _ in UIPasteboard.general.url = url })
        }
        if let value = element.srcUri, let url = URL(string: value) {
            menu.addAction(UIAlertAction(title: "Open Media", style: .default) { _ in self.onOpenURL?(url) })
            menu.addAction(UIAlertAction(title: "Copy Media Address", style: .default) { _ in UIPasteboard.general.url = url })
            if element.type == .image {
                menu.addAction(UIAlertAction(title: "Save Image", style: .default) { _ in self.saveImage(url) })
            }
        }
        if let text = element.textContent, !text.isEmpty {
            menu.addAction(UIAlertAction(title: "Copy Text", style: .default) { _ in UIPasteboard.general.string = text })
        }
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        menu.popoverPresentationController?.sourceView = sourceView
        presenter.present(menu, animated: true)
    }

    private func saveImage(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            URLSession.shared.downloadTask(with: url) { fileURL, _, _ in
                guard let fileURL else { return }
                let suffix = url.pathExtension.isEmpty ? "" : ".\(url.pathExtension)"
                let stagedURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("vulpra-photo-\(UUID().uuidString)\(suffix)")
                do {
                    try FileManager.default.moveItem(at: fileURL, to: stagedURL)
                } catch {
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, fileURL: stagedURL, options: nil)
                } completionHandler: { _, _ in
                    try? FileManager.default.removeItem(at: stagedURL)
                }
            }.resume()
        }
    }
}
