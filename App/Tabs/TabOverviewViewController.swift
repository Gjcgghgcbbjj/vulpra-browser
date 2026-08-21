import UIKit

final class TabOverviewViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let manager: TabManager
    private var collectionView: UICollectionView!
    private let privateControl = UISegmentedControl(items: [L10n.tr("Tabs", "标签页"), L10n.tr("Private", "隐私")])
    private var showingPrivate = false
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
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: L10n.tr("Done", "完成"), style: .done, target: self, action: #selector(done))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTab))
        privateControl.selectedSegmentIndex = 0
        toolbarItems = [
            UIBarButtonItem(title: L10n.tr("Undo Close", "撤销关闭"), style: .plain, target: self, action: #selector(undoClose)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: L10n.tr("Close Others", "关闭其他"), style: .plain, target: self, action: #selector(closeOthers)),
        ]
        navigationController?.setToolbarHidden(false, animated: false)
        privateControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        privateControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(privateControl)

        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 14
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 14, left: 14, bottom: 28, right: 14)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(TabCardCell.self, forCellWithReuseIdentifier: TabCardCell.reuseIdentifier)
        collectionView.dragInteractionEnabled = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            privateControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            privateControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            privateControl.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            collectionView.topAnchor.constraint(equalTo: privateControl.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private var visibleTabs: [BrowserTab] { showingPrivate ? manager.privateTabs : manager.normalTabs }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { visibleTabs.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabCardCell.reuseIdentifier, for: indexPath) as! TabCardCell
        let tab = visibleTabs[indexPath.item]
        cell.update(tab: tab, selected: tab.id == manager.selectedID)
        cell.closeButton.tag = indexPath.item
        cell.closeButton.addTarget(self, action: #selector(closeTab(_:)), for: .touchUpInside)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool { true }

    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let current = visibleTabs
        guard current.indices.contains(sourceIndexPath.item), current.indices.contains(destinationIndexPath.item) else { return }
        manager.move(current[sourceIndexPath.item], before: current[destinationIndexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        manager.select(visibleTabs[indexPath.item])
        dismiss(animated: true, completion: onDismiss)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = traitCollection.horizontalSizeClass == .regular ? 3 : 2
        let width = floor((collectionView.bounds.width - 28 - (columns - 1) * 12) / columns)
        return CGSize(width: width, height: max(190, width * 1.15))
    }

    @objc private func addTab() {
        _ = manager.newTab(url: nil, privateMode: showingPrivate)
        dismiss(animated: true, completion: onDismiss)
    }

    @objc private func closeTab(_ sender: UIButton) {
        guard visibleTabs.indices.contains(sender.tag) else { return }
        manager.close(visibleTabs[sender.tag])
        // #4: Use incremental update instead of reloadData — preserves cell
        // state and gives proper delete animation.
        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: [IndexPath(item: sender.tag, section: 0)])
        }
    }

    @objc private func modeChanged() {
        showingPrivate = privateControl.selectedSegmentIndex == 1
        collectionView.reloadData()
    }

    @objc private func done() { dismiss(animated: true, completion: onDismiss) }

    @objc private func undoClose() {
        manager.undoClose()
        collectionView.performBatchUpdates {
            collectionView.insertItems(at: [IndexPath(item: 0, section: 0)])
        }
    }

    @objc private func closeOthers() {
        guard let selected = manager.selectedTab else { return }
        manager.closeOthers(keeping: selected)
        collectionView.reloadData()
    }
}
