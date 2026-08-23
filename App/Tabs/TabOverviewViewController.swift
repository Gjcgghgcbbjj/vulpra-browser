import UIKit

final class TabOverviewViewController: UIViewController, UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {
    private let manager: TabManager
    private var collectionView: UICollectionView!
    private let privateControl = UISegmentedControl(items: [L10n.tr("Tabs", "标签页"), L10n.tr("Private", "隐私")])
    private let emptyTitle = UILabel()
    private let emptyButton = UIButton(type: .system)
    private var showingPrivate = false
    private var undoToast: UIControl?
    var onDismiss: (() -> Void)?

    init(manager: TabManager) {
        self.manager = manager
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("Tabs", "标签页")
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: L10n.tr("Done", "完成"), style: .done,
                                                           target: self, action: #selector(done))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self, action: #selector(addTab))
        privateControl.selectedSegmentIndex = 0
        toolbarItems = [
            UIBarButtonItem(title: L10n.tr("Undo Close", "撤销关闭"), style: .plain,
                            target: self, action: #selector(undoClose)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: L10n.tr("Close Others", "关闭其他"), style: .plain,
                            target: self, action: #selector(closeOthers)),
        ]
        navigationController?.setToolbarHidden(false, animated: false)
        privateControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        privateControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(privateControl)

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 14
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 28, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(TabCardCell.self, forCellWithReuseIdentifier: TabCardCell.reuseIdentifier)
        collectionView.dragInteractionEnabled = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        configureEmptyState()
        NSLayoutConstraint.activate([
            privateControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            privateControl.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            privateControl.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            collectionView.topAnchor.constraint(equalTo: privateControl.bottomAnchor, constant: 14),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyTitle.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -18),
            emptyTitle.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            emptyTitle.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),
            emptyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyButton.topAnchor.constraint(equalTo: emptyTitle.bottomAnchor, constant: 16),
        ])
        updateEmptyState()
    }

    private var visibleTabs: [BrowserTab] { showingPrivate ? manager.privateTabs : manager.normalTabs }

    private func configureEmptyState() {
        emptyTitle.text = L10n.tr("No tabs here", "这里还没有标签页")
        emptyTitle.font = .preferredFont(forTextStyle: .title3)
        emptyTitle.textColor = .secondaryLabel
        emptyTitle.textAlignment = .center
        var configuration = UIButton.Configuration.gray()
        configuration.title = L10n.tr("New Tab", "新标签页")
        configuration.image = UIImage(systemName: "plus")
        configuration.imagePadding = 7
        configuration.cornerStyle = .capsule
        emptyButton.configuration = configuration
        emptyButton.addTarget(self, action: #selector(addTab), for: .touchUpInside)
        [emptyTitle, emptyButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isHidden = true
            view.addSubview($0)
        }
    }

    private func updateEmptyState() {
        let empty = visibleTabs.isEmpty
        emptyTitle.isHidden = !empty
        emptyButton.isHidden = !empty
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        visibleTabs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabCardCell.reuseIdentifier,
                                                      for: indexPath) as! TabCardCell
        let tab = visibleTabs[indexPath.item]
        cell.update(tab: tab, selected: tab.id == manager.selectedID)
        cell.closeButton.tag = indexPath.item
        cell.closeButton.addTarget(self, action: #selector(closeTab(_:)), for: .touchUpInside)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool { true }

    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath,
                        to destinationIndexPath: IndexPath) {
        let current = visibleTabs
        guard current.indices.contains(sourceIndexPath.item), current.indices.contains(destinationIndexPath.item) else { return }
        manager.move(current[sourceIndexPath.item], before: current[destinationIndexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        manager.select(visibleTabs[indexPath.item])
        dismiss(animated: true, completion: onDismiss)
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        VulpraMotion.spring(damping: 0.6, duration: 0.28) {
            cell.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        VulpraMotion.spring(damping: 0.65, duration: 0.32) {
            cell.transform = .identity
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = traitCollection.horizontalSizeClass == .regular ? 3 : 2
        let availableWidth = collectionView.bounds.width - 32 - (columns - 1) * 12
        let width = floor(max(180, availableWidth / columns))
        return CGSize(width: width, height: max(190, width * 1.12))
    }

    @objc private func addTab() {
        _ = manager.newTab(url: nil, privateMode: showingPrivate)
        dismiss(animated: true, completion: onDismiss)
    }

    @objc private func closeTab(_ sender: UIButton) {
        guard visibleTabs.indices.contains(sender.tag) else { return }
        manager.close(visibleTabs[sender.tag])
        refreshAfterMutation(message: L10n.tr("Tab closed", "已关闭标签页"))
    }

    private func refreshAfterMutation(message: String) {
        collectionView.reloadData()
        updateEmptyState()
        showToast(message: message)
    }

    /// Compact dark capsule with a direct undo action; only one toast is alive at a time.
    private func showToast(message: String) {
        undoToast?.removeFromSuperview()
        let toast = UIControl()
        toast.backgroundColor = UIColor(white: 0.15, alpha: 0.96)
        toast.layer.cornerCurve = .continuous
        toast.layer.cornerRadius = 20
        toast.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        toast.addSubview(label)

        let undo = UIButton(type: .system)
        undo.setTitle(L10n.tr("Undo", "撤销"), for: .normal)
        undo.setTitleColor(VulpraAppearance.accent, for: .normal)
        undo.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        undo.addAction(UIAction { [weak self] _ in
            self?.undoClose()
            self?.undoToast?.removeFromSuperview()
            self?.undoToast = nil
        }, for: .touchUpInside)
        undo.translatesAutoresizingMaskIntoConstraints = false
        toast.addSubview(undo)

        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: toast.topAnchor, constant: 11),
            label.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 17),
            label.trailingAnchor.constraint(equalTo: undo.leadingAnchor, constant: -15),
            undo.centerYAnchor.constraint(equalTo: toast.centerYAnchor),
            undo.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -15),
            undo.widthAnchor.constraint(greaterThanOrEqualToConstant: 34),
            toast.topAnchor.constraint(equalTo: label.topAnchor, constant: -11),
            toast.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: 11),
        ])
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 12)
        UIView.animate(withDuration: 0.25) {
            toast.alpha = 1
            toast.transform = .identity
        }
        undoToast = toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self, weak toast] in
            guard let toast, toast === self?.undoToast else { return }
            UIView.animate(withDuration: 0.25, animations: {
                toast.alpha = 0
                toast.transform = CGAffineTransform(translationX: 0, y: 12)
            }, completion: { _ in
                toast.removeFromSuperview()
                if self?.undoToast === toast { self?.undoToast = nil }
            })
        }
    }

    @objc private func modeChanged() {
        showingPrivate = privateControl.selectedSegmentIndex == 1
        collectionView.reloadData()
        updateEmptyState()
    }

    @objc private func done() { dismiss(animated: true, completion: onDismiss) }

    @objc private func undoClose() {
        manager.undoClose()
        refreshAfterMutation(message: L10n.tr("Tab restored", "已恢复标签页"))
    }

    @objc private func closeOthers() {
        guard let keeper = visibleTabs.first(where: { $0.id == manager.selectedID }) ?? visibleTabs.first else { return }
        manager.closeOthers(keeping: keeper)
        collectionView.reloadData()
        updateEmptyState()
    }
}
