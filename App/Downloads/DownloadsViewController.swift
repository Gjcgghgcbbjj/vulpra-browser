import UIKit

final class DownloadsViewController: UITableViewController {
    private let emptyState = VulpraEmptyStateView(
        symbol: "arrow.down.circle", title: VulpraL10n.text("empty.downloads")
    )

    init() { super.init(style: .insetGrouped) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = VulpraL10n.text("downloads.title")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DownloadCell")
        DownloadManager.shared.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        DownloadManager.shared.records.count
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
    }

    private func refresh() {
        tableView.reloadData()
        tableView.backgroundView = DownloadManager.shared.records.isEmpty ? emptyState : nil
    }

    private func detail(_ record: DownloadRecord) -> String {
        let formatter = ByteCountFormatter()
        let received = formatter.string(fromByteCount: record.receivedBytes)
        if let expected = record.expectedBytes {
            return VulpraL10n.format(
                "downloads.progress.total", record.state.localizedTitle,
                received, formatter.string(fromByteCount: expected)
            )
        }
        return VulpraL10n.format("downloads.progress.received", record.state.localizedTitle, received)
    }
}
