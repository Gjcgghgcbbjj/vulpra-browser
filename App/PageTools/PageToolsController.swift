import UIKit

protocol PageToolsControllerDelegate: AnyObject {
    func pageToolsDidRequestShare(_ controller: PageToolsController)
    func pageToolsDidRequestBookmark(_ controller: PageToolsController)
    func pageToolsDidRequestDesktopMode(_ controller: PageToolsController)
    func pageTools(_ controller: PageToolsController, setZoom level: Int)
    func pageToolsDidRequestQRScanner(_ controller: PageToolsController)
}

final class PageToolsController {
    weak var delegate: PageToolsControllerDelegate?

    func present(from presenter: UIViewController, sourceView: UIView?, url: URL?) {
        let menu = UIAlertController(title: url?.host ?? VulpraL10n.text("page_tools.title"), message: nil, preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: VulpraL10n.text("page_tools.share"), style: .default) { _ in self.delegate?.pageToolsDidRequestShare(self) })
        menu.addAction(UIAlertAction(title: VulpraL10n.text("page_tools.add_bookmark"), style: .default) { _ in self.delegate?.pageToolsDidRequestBookmark(self) })
        menu.addAction(UIAlertAction(title: VulpraL10n.text("page_tools.request_desktop"), style: .default) { _ in self.delegate?.pageToolsDidRequestDesktopMode(self) })
        menu.addAction(UIAlertAction(title: VulpraL10n.text("page_tools.page_zoom"), style: .default) { _ in self.askZoom(from: presenter) })
        menu.addAction(UIAlertAction(title: VulpraL10n.text("page_tools.scan_qr"), style: .default) { _ in self.delegate?.pageToolsDidRequestQRScanner(self) })
        if let url {
            menu.addAction(UIAlertAction(title: VulpraL10n.text("page_tools.copy_link"), style: .default) { _ in UIPasteboard.general.url = url })
        }
        menu.addAction(UIAlertAction(title: VulpraL10n.text("common.cancel"), style: .cancel))
        menu.popoverPresentationController?.sourceView = sourceView ?? presenter.view
        presenter.present(menu, animated: true)
    }

    private func askZoom(from presenter: UIViewController) {
        let alert = UIAlertController(title: VulpraL10n.text("page_tools.page_zoom"), message: nil, preferredStyle: .actionSheet)
        [75, 90, 100, 110, 125, 150].forEach { level in
            alert.addAction(UIAlertAction(title: VulpraL10n.format("settings.page_zoom.value", level), style: .default) { _ in self.delegate?.pageTools(self, setZoom: level) })
        }
        alert.addAction(UIAlertAction(title: VulpraL10n.text("common.cancel"), style: .cancel))
        alert.popoverPresentationController?.sourceView = presenter.view
        presenter.present(alert, animated: true)
    }
}
