import UIKit

protocol PageToolsControllerDelegate: AnyObject {
    func pageToolsDidRequestShare(_ controller: PageToolsController)
    func pageToolsDidRequestBookmark(_ controller: PageToolsController)
    func pageTools(_ controller: PageToolsController, find text: String)
    func pageToolsDidRequestDesktopMode(_ controller: PageToolsController)
    func pageTools(_ controller: PageToolsController, setZoom level: Int)
    func pageToolsDidRequestQRScanner(_ controller: PageToolsController)
    func pageToolsDidRequestPictureInPicture(_ controller: PageToolsController)
    func pageToolsDidRequestReaderMode(_ controller: PageToolsController)
}

final class PageToolsController {
    weak var delegate: PageToolsControllerDelegate?

    func present(from presenter: UIViewController, sourceView: UIView?, url: URL?) {
        let menu = UIAlertController(title: url?.host ?? L10n.tr("Page Tools", "页面工具"), message: nil, preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: L10n.tr("Share", "分享"), style: .default) { _ in self.delegate?.pageToolsDidRequestShare(self) })
        menu.addAction(UIAlertAction(title: L10n.tr("Add Bookmark", "添加书签"), style: .default) { _ in self.delegate?.pageToolsDidRequestBookmark(self) })
        menu.addAction(UIAlertAction(title: L10n.tr("Find in Page", "页面内查找"), style: .default) { _ in self.askFind(from: presenter) })
        menu.addAction(UIAlertAction(title: L10n.tr("Request Desktop Site", "请求桌面版网站"), style: .default) { _ in self.delegate?.pageToolsDidRequestDesktopMode(self) })
        menu.addAction(UIAlertAction(title: L10n.tr("Page Zoom", "页面缩放"), style: .default) { _ in self.askZoom(from: presenter) })
        menu.addAction(UIAlertAction(title: L10n.tr("Picture in Picture", "画中画"), style: .default) { _ in self.delegate?.pageToolsDidRequestPictureInPicture(self) })
        menu.addAction(UIAlertAction(title: L10n.tr("Reader Mode", "阅读模式"), style: .default) { _ in self.delegate?.pageToolsDidRequestReaderMode(self) })
        menu.addAction(UIAlertAction(title: L10n.tr("Scan QR Code", "扫描二维码"), style: .default) { _ in self.delegate?.pageToolsDidRequestQRScanner(self) })
        if let url {
            menu.addAction(UIAlertAction(title: L10n.tr("Copy Link", "拷贝链接"), style: .default) { _ in UIPasteboard.general.url = url })
        }
        menu.addAction(UIAlertAction(title: L10n.tr("Cancel", "取消"), style: .cancel))
        menu.popoverPresentationController?.sourceView = sourceView ?? presenter.view
        presenter.present(menu, animated: true)
    }

    private func askFind(from presenter: UIViewController) {
        let alert = UIAlertController(title: "Find in Page", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Text" }
        alert.addAction(UIAlertAction(title: "Find", style: .default) { _ in
            self.delegate?.pageTools(self, find: alert.textFields?.first?.text ?? "")
        })
        alert.addAction(UIAlertAction(title: L10n.tr("Cancel", "取消"), style: .cancel))
        presenter.present(alert, animated: true)
    }

    private func askZoom(from presenter: UIViewController) {
        let alert = UIAlertController(title: "Page Zoom", message: nil, preferredStyle: .actionSheet)
        [75, 90, 100, 110, 125, 150].forEach { level in
            alert.addAction(UIAlertAction(title: "\(level)%", style: .default) { _ in self.delegate?.pageTools(self, setZoom: level) })
        }
        alert.addAction(UIAlertAction(title: L10n.tr("Cancel", "取消"), style: .cancel))
        alert.popoverPresentationController?.sourceView = presenter.view
        presenter.present(alert, animated: true)
    }
}
