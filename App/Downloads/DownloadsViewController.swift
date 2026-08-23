import UIKit

final class DownloadsViewController: UITableViewController {
    private let emptyIcon = UIImageView(image: UIImage(systemName: "arrow.down.circle"))
    private let emptyTitle = UILabel()
    private let emptyHint = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("Downloads", "下载")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DownloadCell")
        DownloadManager.shared.onChange = { [weak self] in self?.tableView.reloadData() }
        configureEmptyState()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = DownloadManager.shared.records.count
        updateEmptyState(count: count)
        return count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let record = DownloadManager.shared.records[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownloadCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = record.filename
        content.secondaryText = detail(record)
        content.image = UIImage(systemName: record.state == .complete ? "checkmark.circle" : "arrow.down.circle")
        cell.contentConfiguration = content
        cell.accessoryType = record.state == .complete ? .disclosureIndicator : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let record = DownloadManager.shared.records[indexPath.row]
        guard record.state == .complete, FileManager.default.fileExists(atPath: record.localPath) else { return }
        let share = UIActivityViewController(activityItems: [URL(fileURLWithPath: record.localPath)], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
        present(share, animated: true)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        DownloadManager.shared.remove(DownloadManager.shared.records[indexPath.row], deleteFile: true)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    private func configureEmptyState() {
        emptyIcon.tintColor = .tertiaryLabel
        emptyIcon.contentMode = .center
        emptyTitle.text = L10n.tr("No downloads", "还没有下载")
        emptyTitle.font = .preferredFont(forTextStyle: .title3)
        emptyTitle.textColor = .secondaryLabel
        emptyTitle.textAlignment = .center
        emptyHint.text = L10n.tr("Files you download will appear here.", "下载的文件会出现在这里。")
        emptyHint.font = .preferredFont(forTextStyle: .footnote)
        emptyHint.textColor = .tertiaryLabel
        emptyHint.textAlignment = .center
        [emptyIcon, emptyTitle, emptyHint].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isHidden = true
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            emptyIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyIcon.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -44),
            emptyIcon.heightAnchor.constraint(equalToConstant: 44),
            emptyTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyTitle.topAnchor.constraint(equalTo: emptyIcon.bottomAnchor, constant: 14),
            emptyTitle.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            emptyHint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyHint.topAnchor.constraint(equalTo: emptyTitle.bottomAnchor, constant: 6),
            emptyHint.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
        ])
    }

    private func updateEmptyState(count: Int) {
        let empty = count == 0
        emptyIcon.isHidden = !empty
        emptyTitle.isHidden = !empty
        emptyHint.isHidden = !empty
    }

    private func detail(_ record: DownloadRecord) -> String {
        let formatter = ByteCountFormatter()
        let received = formatter.string(fromByteCount: record.receivedBytes)
        let state = localizedState(record.state)
        if let expected = record.expectedBytes {
            return "\(state) · \(received) / \(formatter.string(fromByteCount: expected))"
        }
        return "\(state) · \(received)"
    }

    private func localizedState(_ state: DownloadRecord.State) -> String {
        switch state {
        case .active: return L10n.tr("Active", "下载中")
        case .complete: return L10n.tr("Complete", "已完成")
        case .failed: return L10n.tr("Failed", "失败")
        case .cancelled: return L10n.tr("Cancelled", "已取消")
        }
    }
}
