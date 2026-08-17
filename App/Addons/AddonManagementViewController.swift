import GeckoView
import UniformTypeIdentifiers
import UIKit

final class AddonManagementViewController: UITableViewController, UIDocumentPickerDelegate {
    private var addons: [Addon] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Extensions"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(install))
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AddonCell")
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .browserAddonsDidChange, object: nil)
        refresh()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { addons.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let addon = addons[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "AddonCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = addon.metaData.name ?? addon.id
        content.secondaryText = "Version \(addon.metaData.version)"
        content.image = UIImage(systemName: "puzzlepiece.extension")
        let toggle = UISwitch()
        toggle.isOn = addon.metaData.enabled
        toggle.isEnabled = addon.metaData.canBeEnabled
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(toggle(_:)), for: .valueChanged)
        cell.contentConfiguration = content
        cell.accessoryView = toggle
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let addon = addons[indexPath.row]
        Task { try? await AddonRuntime.shared.uninstall(addon); await reloadAddons() }
    }

    @objc private func refresh() { Task { await reloadAddons() } }

    @MainActor
    private func reloadAddons() async {
        addons = (try? await AddonRuntime.shared.list())?.filter { !$0.isBuiltIn } ?? []
        tableView.reloadData()
    }

    @objc private func toggle(_ sender: UISwitch) {
        guard addons.indices.contains(sender.tag) else { return }
        let addon = addons[sender.tag]
        Task {
            if sender.isOn { _ = try? await AddonRuntime.shared.enable(addon) }
            else { _ = try? await AddonRuntime.shared.disable(addon) }
            await reloadAddons()
        }
    }

    @objc private func install() {
        let type = UTType(filenameExtension: "xpi") ?? .data
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [type], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        Task { _ = try? await AddonRuntime.shared.install(url: url.absoluteString); await reloadAddons() }
    }
}
