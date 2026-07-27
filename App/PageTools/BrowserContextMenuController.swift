import Photos
import UIKit
import VulpraEngineKit

final class BrowserContextMenuController {
    var onOpenURL: ((URL) -> Void)?

    func present(element: EngineContextMenuElement, from presenter: UIViewController, sourceView: UIView) {
        let menu = UIAlertController(title: element.title, message: nil, preferredStyle: .actionSheet)
        if let url = element.linkURL {
            menu.addAction(UIAlertAction(title: VulpraL10n.text("page_tools.open_link"), style: .default) { _ in self.onOpenURL?(url) })
            menu.addAction(UIAlertAction(title: VulpraL10n.text("page_tools.copy_link"), style: .default) { _ in UIPasteboard.general.url = url })
        }
        if let url = element.imageURL {
            menu.addAction(UIAlertAction(title: VulpraL10n.text("page_tools.open_image"), style: .default) { _ in self.onOpenURL?(url) })
            menu.addAction(UIAlertAction(title: VulpraL10n.text("page_tools.save_image"), style: .default) { _ in self.saveImage(url) })
        }
        menu.addAction(UIAlertAction(title: VulpraL10n.text("common.cancel"), style: .cancel))
        menu.popoverPresentationController?.sourceView = sourceView
        presenter.present(menu, animated: true)
    }

    private func saveImage(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let image = UIImage(data: data) else { return }
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }.resume()
        }
    }
}
