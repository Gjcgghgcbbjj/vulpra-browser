import UIKit
import PhotosUI

/// Wallpaper picker: preset rows preview through the same live
/// `CAGradientLayer` rendering the start page uses — what you see in the
/// list is exactly what you get, at any size.
final class WallpaperPickerViewController: UITableViewController {
    private let presets: [Wallpaper] = [.none, .sunset, .ocean, .forest, .night]

    private var current: Wallpaper {
        Wallpaper(rawValue: BrowserSettingsStore.shared.value.wallpaper) ?? .none
    }

    init() { super.init(style: .insetGrouped) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("Home Wallpaper", "首页壁纸")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? presets.count : 1
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1 ? L10n.tr("Photos stay on this device.", "照片只保存在本机。") : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        if indexPath.section == 0 {
            let option = presets[indexPath.row]
            config.text = option.displayName
            let swatch = GradientSwatch(option: option)
            swatch.frame = CGRect(x: 0, y: 0, width: 28, height: 28)
            swatch.layer.cornerRadius = 6
            swatch.clipsToBounds = true
            cell.accessoryView = option == .none ? nil : swatch
            cell.imageView?.image = option == .none ? UIImage(systemName: "slash.circle") : nil
        } else {
            config.text = Wallpaper.photo.displayName
            if let photo = Wallpaper.loadPhoto() {
                config.secondaryText = L10n.tr("Saved", "已保存")
                let thumb = UIImageView(image: photo)
                thumb.frame = CGRect(x: 0, y: 0, width: 28, height: 28)
                thumb.contentMode = .scaleAspectFill
                thumb.clipsToBounds = true
                thumb.layer.cornerRadius = 6
                cell.accessoryView = thumb
            } else {
                config.secondaryText = L10n.tr("Pick from your library", "从相册选择")
                cell.accessoryView = nil
            }
            cell.imageView?.image = UIImage(systemName: "photo")
        }
        cell.contentConfiguration = config

        let selected = indexPath.section == 0 ? presets[indexPath.row] : Wallpaper.photo
        cell.accessoryType = selected == current ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            select(presets[indexPath.row])
        } else {
            presentPhotoPicker()
        }
    }

    // MARK: - Selection

    private func select(_ option: Wallpaper) {
        guard option != current else { return }
        BrowserSettingsStore.shared.update { $0.wallpaper = option.rawValue }
        NotificationCenter.default.post(name: .vulpraWallpaperDidChange, object: nil)
        tableView.reloadData()
    }

    // MARK: - Photo picking

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func showPickError(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("OK", "好"), style: .default))
        present(alert, animated: true)
    }
}

extension WallpaperPickerViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async {
                guard let image = object as? UIImage else {
                    self?.showPickError(message: L10n.tr("Could not load that photo.", "无法读取该照片。"))
                    return
                }
                Wallpaper.invalidateCachedPhoto()
                guard Wallpaper.storePhoto(image) else {
                    self?.showPickError(message: L10n.tr("Could not save the wallpaper.", "壁纸保存失败。"))
                    return
                }
                self?.select(.photo)
            }
        }
    }
}

// MARK: - Swatch

/// Tiny live-gradient tile for picker rows; same layer pipeline as the page.
private final class GradientSwatch: UIView {
    private let gradient = CAGradientLayer()

    init(option: Wallpaper) {
        super.init(frame: .zero)
        gradient.colors = option.gradientColors ?? []
        gradient.startPoint = CGPoint(x: 0.15, y: 0.05)
        gradient.endPoint = CGPoint(x: 0.85, y: 0.95)
        layer.addSublayer(gradient)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    // The cell sizes this view after init; laying out from bounds here means
    // the gradient is never stuck at the zero frame it was born with.
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
    }
}
