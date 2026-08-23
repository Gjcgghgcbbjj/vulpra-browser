protocol PageToolsControllerDelegate: AnyObject {
    func pageToolsDidRequestBookmarks(_ controller: PageToolsController)
    func pageToolsDidRequestHistory(_ controller: PageToolsController)
    func pageToolsDidRequestDownloads(_ controller: PageToolsController)
    func pageToolsDidRequestPrivateTab(_ controller: PageToolsController)
    func pageToolsDidRequestSettings(_ controller: PageToolsController)
    func pageToolsDidRequestShare(_ controller: PageToolsController)
    func pageToolsDidRequestBookmark(_ controller: PageToolsController)
    func pageTools(_ controller: PageToolsController, find text: String)
    func pageToolsDidRequestDesktopMode(_ controller: PageToolsController)
    func pageTools(_ controller: PageToolsController, setZoom level: Int)
    func pageToolsDidRequestQRScanner(_ controller: PageToolsController)
    func pageToolsDidRequestPictureInPicture(_ controller: PageToolsController)
    func pageToolsDidRequestReaderMode(_ controller: PageToolsController)
    func pageToolsDidRequestGoBack(_ controller: PageToolsController)
    func pageToolsDidRequestGoForward(_ controller: PageToolsController)
    func pageToolsDidRequestReloadOrStop(_ controller: PageToolsController)
}

final class PageToolsController {
    weak var delegate: PageToolsControllerDelegate?

    func present(from presenter: UIViewController, sourceView: UIView?, url: URL?,
                 isLoading: Bool = false, canGoBack: Bool = false, canGoForward: Bool = false) {
        var navigationItems: [VulpraCommandItem] = []
        if canGoBack {
            navigationItems.append(action(L10n.tr("Back", "后退"), "chevron.backward") { [weak self] in
                guard let self else { return }; self.delegate?.pageToolsDidRequestGoBack(self)
            })
        }
        if canGoForward {
            navigationItems.append(action(L10n.tr("Forward", "前进"), "chevron.forward") { [weak self] in
                guard let self else { return }; self.delegate?.pageToolsDidRequestGoForward(self)
            })
        }
        navigationItems.append(action(isLoading ? L10n.tr("Stop", "停止") : L10n.tr("Reload", "重新加载"),
                                      isLoading ? "stop.fill" : "arrow.clockwise") { [weak self] in
            guard let self else { return }; self.delegate?.pageToolsDidRequestReloadOrStop(self)
        })

        let pageActions: [VulpraCommandItem]
        if let url {
            pageActions = [
                action(L10n.tr("Share", "分享"), "square.and.arrow.up") { [weak self] in
                    guard let self else { return }; self.delegate?.pageToolsDidRequestShare(self)
                },
                action(L10n.tr("Add Bookmark", "添加书签"), "bookmark") { [weak self] in
                    guard let self else { return }; self.delegate?.pageToolsDidRequestBookmark(self)
                },
                action(L10n.tr("Find in Page", "页面内查找"), "text.magnifyingglass") { [weak self] in
                    guard let self else { return }; self.askFind(from: presenter)
                },
                action(L10n.tr("Reader Mode", "阅读模式"), "doc.richtext") { [weak self] in
                    guard let self else { return }; self.delegate?.pageToolsDidRequestReaderMode(self)
                },
                action(L10n.tr("Request Desktop Site", "请求桌面版网站"), "desktopcomputer") { [weak self] in
                    guard let self else { return }; self.delegate?.pageToolsDidRequestDesktopMode(self)
                },
                action(L10n.tr("Copy Link", "拷贝链接"), "link") { UIPasteboard.general.url = url },
            ]
        } else {
            pageActions = []
        }

        let mediaActions = [
            action(L10n.tr("Picture in Picture", "画中画"), "rectangle.on.rectangle") { [weak self] in
                guard let self else { return }; self.delegate?.pageToolsDidRequestPictureInPicture(self)
            },
            action(L10n.tr("Scan QR Code", "扫描二维码"), "qrcode.viewfinder") { [weak self] in
                guard let self else { return }; self.delegate?.pageToolsDidRequestQRScanner(self)
            },
        ]

        let browserActions = [
            action(L10n.tr("New Private Tab", "新建私密标签页"), "eyeglasses") { [weak self] in
                guard let self else { return }; self.delegate?.pageToolsDidRequestPrivateTab(self)
            },
            action(L10n.tr("Bookmarks", "书签"), "book") { [weak self] in
                guard let self else { return }; self.delegate?.pageToolsDidRequestBookmarks(self)
            },
            action(L10n.tr("History", "历史记录"), "clock.arrow.circlepath") { [weak self] in
                guard let self else { return }; self.delegate?.pageToolsDidRequestHistory(self)
            },
            action(L10n.tr("Downloads", "下载"), "arrow.down.circle") { [weak self] in
                guard let self else { return }; self.delegate?.pageToolsDidRequestDownloads(self)
            },
            action(L10n.tr("Settings", "设置"), "gearshape") { [weak self] in
                guard let self else { return }; self.delegate?.pageToolsDidRequestSettings(self)
            },
        ]
        let zoomAction = action(L10n.tr("Page Zoom", "页面缩放"), "plus.magnifyingglass") { [weak self] in
            guard let self else { return }; self.askZoom(from: presenter)
        }

        var sections = [VulpraCommandSection(header: L10n.tr("Navigation", "导航"), items: navigationItems)]
        if !pageActions.isEmpty {
            sections.append(VulpraCommandSection(header: L10n.tr("Page", "页面"),
                                                 items: pageActions + [zoomAction]))
        }
        sections.append(VulpraCommandSection(header: L10n.tr("Media", "媒体"), items: mediaActions))
        sections.append(VulpraCommandSection(header: L10n.tr("Browser", "浏览器"), items: browserActions))

        let sheet = VulpraCommandSheet(
            title: url?.host ?? L10n.tr("Vulpra", "Vulpra"),
            subtitle: L10n.tr("Commands", "命令"),
            sections: sections
        )
        sheet.modalPresentationStyle = .formSheet
        sheet.sheetPresentationController?.prefersGrabberVisible = true
        sheet.sheetPresentationController?.detents = [.medium(), .large()]
        presenter.present(sheet, animated: true)
    }

    private func action(_ title: String, _ symbol: String, handler: @escaping () -> Void) -> VulpraCommandItem {
        VulpraCommandItem(title: title, symbol: symbol, handler: handler)
    }

    private func askFind(from presenter: UIViewController) {
        let alert = UIAlertController(title: L10n.tr("Find in Page", "页面内查找"), message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = L10n.tr("Text", "文字") }
        alert.addAction(UIAlertAction(title: L10n.tr("Find", "查找"), style: .default) { _ in
            self.delegate?.pageTools(self, find: alert.textFields?.first?.text ?? "")
        })
        alert.addAction(UIAlertAction(title: L10n.tr("Cancel", "取消"), style: .cancel))
        presenter.present(alert, animated: true)
    }

    private func askZoom(from presenter: UIViewController) {
        let current = BrowserSettingsStore.shared.value.pageZoom
        let levels = [75, 90, 100, 110, 125, 150]
        let items = levels.map { level in
            VulpraCommandItem(
                title: "\(level)%",
                subtitle: level == current ? "" : nil,
                symbol: level == current ? "checkmark" : "circle.dashed",
                handler: { [weak self] in
                    guard let self else { return }
                    self.delegate?.pageTools(self, setZoom: level)
                }
            )
        }
        let sheet = VulpraCommandSheet(
            title: L10n.tr("Page Zoom", "页面缩放"),
            subtitle: nil,
            sections: [.init(header: nil, items: items)]
        )
        sheet.modalPresentationStyle = .formSheet
        sheet.sheetPresentationController?.prefersGrabberVisible = true
        sheet.sheetPresentationController?.detents = [.medium()]
        presenter.present(sheet, animated: true)
    }
}
