import UIKit

final class DownloadsViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloads"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DownloadCell")
        DownloadManager.shared.onChange = { [weak self] in self?.tableView.reloadData() }
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
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    private func detail(_ record: DownloadRecord) -> String {
        let formatter = ByteCountFormatter()
        let received = formatter.string(fromByteCount: record.receivedBytes)
        if let expected = record.expectedBytes {
            return "\(record.state.rawValue.capitalized) · \(received) of \(formatter.string(fromByteCount: expected))"
        }
        return "\(record.state.rawValue.capitalized) · \(received)"
    }
}
