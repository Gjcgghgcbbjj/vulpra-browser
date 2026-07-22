import UIKit

protocol PageToolsControllerDelegate: AnyObject {
    func pageToolsDidRequestShare(_ controller: PageToolsController)
    func pageToolsDidRequestBookmark(_ controller: PageToolsController)
    func pageTools(_ controller: PageToolsController, find text: String)
    func pageToolsDidRequestDesktopMode(_ controller: PageToolsController)
    func pageTools(_ controller: PageToolsController, setZoom level: Int)
    func pageToolsDidRequestQRScanner(_ controller: PageToolsController)
    func pageToolsDidRequestPictureInPicture(_ controller: PageToolsController)
}

final class PageToolsController {
    weak var delegate: PageToolsControllerDelegate?

    func present(from presenter: UIViewController, sourceView: UIView?, url: URL?) {
        let menu = UIAlertController(title: url?.host ?? "Page Tools", message: nil, preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: "Share", style: .default) { _ in self.delegate?.pageToolsDidRequestShare(self) })
        menu.addAction(UIAlertAction(title: "Add Bookmark", style: .default) { _ in self.delegate?.pageToolsDidRequestBookmark(self) })
        menu.addAction(UIAlertAction(title: "Find in Page", style: .default) { _ in self.askFind(from: presenter) })
        menu.addAction(UIAlertAction(title: "Request Desktop Site", style: .default) { _ in self.delegate?.pageToolsDidRequestDesktopMode(self) })
        menu.addAction(UIAlertAction(title: "Page Zoom", style: .default) { _ in self.askZoom(from: presenter) })
        menu.addAction(UIAlertAction(title: "Picture in Picture", style: .default) { _ in self.delegate?.pageToolsDidRequestPictureInPicture(self) })
        menu.addAction(UIAlertAction(title: "Scan QR Code", style: .default) { _ in self.delegate?.pageToolsDidRequestQRScanner(self) })
        if let url {
            menu.addAction(UIAlertAction(title: "Copy Link", style: .default) { _ in UIPasteboard.general.url = url })
        }
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        menu.popoverPresentationController?.sourceView = sourceView ?? presenter.view
        presenter.present(menu, animated: true)
    }

    private func askFind(from presenter: UIViewController) {
        let alert = UIAlertController(title: "Find in Page", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Text" }
        alert.addAction(UIAlertAction(title: "Find", style: .default) { _ in
            self.delegate?.pageTools(self, find: alert.textFields?.first?.text ?? "")
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        presenter.present(alert, animated: true)
    }

    private func askZoom(from presenter: UIViewController) {
        let alert = UIAlertController(title: "Page Zoom", message: nil, preferredStyle: .actionSheet)
        [75, 90, 100, 110, 125, 150].forEach { level in
            alert.addAction(UIAlertAction(title: "\(level)%", style: .default) { _ in self.delegate?.pageTools(self, setZoom: level) })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = presenter.view
        presenter.present(alert, animated: true)
    }
}
