import UIKit

protocol PageToolsControllerDelegate: AnyObject {
    func pageToolsDidRequestBookmarks(_ controller: PageToolsController)
    func pageToolsDidRequestHistory(_ controller: PageToolsController)
    func pageToolsDidRequestDownloads(_ controller: PageToolsController)
    func pageToolsDidRequestPrivateTab(_ controller: PageToolsController)
    func pageToolsDidRequestSettings(_ controller: PageToolsController)
    func pageToolsDidRequestShare(_ controller: PageToolsController)
    func pageToolsDidRequestBookmark(_ controller: PageToolsController)
    func pageToolsDidRequestFindInPage(_ controller: PageToolsController)
    func pageToolsDidRequestDesktopMode(_ controller: PageToolsController)
    func pageTools(_ controller: PageToolsController, setZoom level: Int)
    func pageToolsDidRequestQRScanner(_ controller: PageToolsController)
    func pageToolsDidRequestPictureInPicture(_ controller: PageToolsController)
    func pageToolsDidRequestReaderMode(_ controller: PageToolsController)
    func pageToolsDidRequestGoBack(_ controller: PageToolsController)
    func pageToolsDidRequestGoForward(_ controller: PageToolsController)
    func pageToolsDidRequestReloadOrStop(_ controller: PageToolsController)
}

/// v24 builds every command as a system UIMenu. iOS owns the presentation,
/// so overlapping presentations — the intermittent crash source of the old
/// custom sheet — cannot happen by construction.
final class PageToolsController {
    weak var delegate: PageToolsControllerDelegate?

    func menu(url: URL?, isLoading: Bool, canGoBack: Bool, canGoForward: Bool,
              zoomLevel: Int) -> UIMenu {
        var navigation: [UIMenuElement] = []
        if canGoBack {
            navigation.append(action(L10n.tr("Back", "后退"), "chevron.backward") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestGoBack(self)
            })
        }
        if canGoForward {
            navigation.append(action(L10n.tr("Forward", "前进"), "chevron.forward") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestGoForward(self)
            })
        }
        navigation.append(action(isLoading ? L10n.tr("Stop", "停止") : L10n.tr("Reload", "重新加载"),
                                 isLoading ? "stop.fill" : "arrow.clockwise") { [weak self] in
            guard let self else { return }
            self.delegate?.pageToolsDidRequestReloadOrStop(self)
        })

        var page: [UIMenuElement] = []
        if url != nil {
            page.append(action(L10n.tr("Share", "分享"), "square.and.arrow.up") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestShare(self)
            })
            page.append(action(L10n.tr("Add Bookmark", "添加书签"), "bookmark") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestBookmark(self)
            })
            page.append(action(L10n.tr("Find in Page", "页面内查找"), "text.magnifyingglass") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestFindInPage(self)
            })
            page.append(action(L10n.tr("Reader Mode", "阅读模式"), "doc.richtext") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestReaderMode(self)
            })
            page.append(action(L10n.tr("Request Desktop Site", "请求桌面版网站"), "desktopcomputer") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestDesktopMode(self)
            })
            page.append(UIAction(title: L10n.tr("Copy Link", "拷贝链接"),
                                 image: UIImage(systemName: "link")) { _ in
                UIPasteboard.general.url = url
            })
        }

        let zoomMenu = UIMenu(options: .displayInline, children: [
            UIMenu(title: L10n.tr("Page Zoom", "页面缩放"),
                   image: UIImage(systemName: "plus.magnifyingglass"),
                   children: [75, 90, 100, 110, 125, 150].map { level in
                UIAction(title: "\(level)%", state: level == zoomLevel ? .on : .off) { [weak self] _ in
                    guard let self else { return }
                    self.delegate?.pageTools(self, setZoom: level)
                }
            }),
        ])

        let media = UIMenu(options: .displayInline, children: [
            action(L10n.tr("Picture in Picture", "画中画"), "rectangle.on.rectangle") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestPictureInPicture(self)
            },
            action(L10n.tr("Scan QR Code", "扫描二维码"), "qrcode.viewfinder") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestQRScanner(self)
            },
        ])

        let browser = UIMenu(options: .displayInline, children: [
            action(L10n.tr("New Private Tab", "新建私密标签页"), "eyeglasses") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestPrivateTab(self)
            },
            action(L10n.tr("Bookmarks", "书签"), "book") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestBookmarks(self)
            },
            action(L10n.tr("History", "历史记录"), "clock.arrow.circlepath") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestHistory(self)
            },
            action(L10n.tr("Downloads", "下载"), "arrow.down.circle") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestDownloads(self)
            },
            action(L10n.tr("Settings", "设置"), "gearshape") { [weak self] in
                guard let self else { return }
                self.delegate?.pageToolsDidRequestSettings(self)
            },
        ])

        var sections = [UIMenu(options: .displayInline, children: navigation)]
        if !page.isEmpty {
            sections.append(UIMenu(options: .displayInline, children: page))
            sections.append(zoomMenu)
        }
        sections.append(media)
        sections.append(browser)
        return UIMenu(children: sections)
    }

    private func action(_ title: String, _ symbol: String,
                        handler: @escaping () -> Void) -> UIAction {
        UIAction(title: title, image: UIImage(systemName: symbol)) { _ in handler() }
    }
}
