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
        var items = [
            PageToolItem(symbol: "square.and.arrow.up", titleKey: "page_tools.share") {
                self.delegate?.pageToolsDidRequestShare(self)
            },
            PageToolItem(symbol: "star", titleKey: "page_tools.add_bookmark") {
                self.delegate?.pageToolsDidRequestBookmark(self)
            },
            PageToolItem(symbol: "desktopcomputer", titleKey: "page_tools.request_desktop") {
                self.delegate?.pageToolsDidRequestDesktopMode(self)
            },
            PageToolItem(symbol: "textformat.size", titleKey: "page_tools.page_zoom") {
                self.askZoom(from: presenter)
            },
            PageToolItem(symbol: "qrcode.viewfinder", titleKey: "page_tools.scan_qr") {
                self.delegate?.pageToolsDidRequestQRScanner(self)
            },
        ]
        if let url {
            items.append(PageToolItem(symbol: "doc.on.doc", titleKey: "page_tools.copy_link") {
                UIPasteboard.general.url = url
            })
        }
        let sheet = PageToolsSheetViewController(
            title: url?.host ?? VulpraL10n.text("page_tools.title"), items: items
        )
        let navigation = UINavigationController(rootViewController: sheet)
        navigation.modalPresentationStyle = .pageSheet
        navigation.popoverPresentationController?.sourceView = sourceView ?? presenter.view
        if let presentation = navigation.sheetPresentationController {
            presentation.detents = [.medium()]
            presentation.prefersGrabberVisible = true
        }
        presenter.present(navigation, animated: true)
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

private struct PageToolItem {
    let symbol: String
    let title: String
    let action: () -> Void

    init(symbol: String, titleKey: String, action: @escaping () -> Void) {
        self.symbol = symbol
        title = VulpraL10n.text(titleKey)
        self.action = action
    }
}

private final class PageToolsSheetViewController: UITableViewController {
    private let items: [PageToolItem]

    init(title: String, items: [PageToolItem]) {
        self.items = items
        super.init(style: .insetGrouped)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tintColor = VulpraAppearance.graphite
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PageToolCell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(close)
        )
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "PageToolCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = item.title
        content.image = UIImage(systemName: item.symbol)
        content.imageProperties.tintColor = VulpraAppearance.graphite
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        tableView.deselectRow(at: indexPath, animated: true)
        dismiss(animated: true, completion: item.action)
    }

    @objc private func close() { dismiss(animated: true) }
}
