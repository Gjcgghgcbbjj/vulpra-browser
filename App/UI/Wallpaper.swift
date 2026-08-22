import UIKit
import PhotosUI

/// Via-style start-page wallpaper: five built-in gradients plus a user photo.
/// The chosen photo is scaled once and stored in Documents; only its id lives
/// in settings so the settings store stays tiny.
enum Wallpaper: String, CaseIterable {
    case none
    case sunset
    case ocean
    case forest
    case night
    case photo

    static let photoFileURL = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask
    )[0].appendingPathComponent("vulpra-wallpaper.png")

    var displayName: String {
        switch self {
        case .none: return L10n.tr("Default", "默认")
        case .sunset: return L10n.tr("Sunset", "日落")
        case .ocean: return L10n.tr("Ocean", "海洋")
        case .forest: return L10n.tr("Forest", "森林")
        case .night: return L10n.tr("Night", "夜空")
        case .photo: return L10n.tr("Custom Photo", "自定义照片")
        }
    }

    /// True when content on top should use light text and stronger blur.
    var isDark: Bool {
        switch self {
        case .sunset, .ocean, .forest, .night, .photo: return true
        case .none: return false
        }
    }

    private var gradientColors: [UIColor]? {
        switch self {
        case .none: return nil
        case .sunset:
            return [UIColor(red: 1.00, green: 0.55, blue: 0.40, alpha: 1),
                    UIColor(red: 0.85, green: 0.30, blue: 0.45, alpha: 1),
                    UIColor(red: 0.35, green: 0.20, blue: 0.45, alpha: 1)]
        case .ocean:
            return [UIColor(red: 0.25, green: 0.65, blue: 0.90, alpha: 1),
                    UIColor(red: 0.12, green: 0.35, blue: 0.65, alpha: 1),
                    UIColor(red: 0.05, green: 0.15, blue: 0.35, alpha: 1)]
        case .forest:
            return [UIColor(red: 0.45, green: 0.75, blue: 0.50, alpha: 1),
                    UIColor(red: 0.20, green: 0.45, blue: 0.35, alpha: 1),
                    UIColor(red: 0.08, green: 0.22, blue: 0.18, alpha: 1)]
        case .night:
            return [UIColor(red: 0.15, green: 0.18, blue: 0.35, alpha: 1),
                    UIColor(red: 0.07, green: 0.08, blue: 0.18, alpha: 1),
                    UIColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1)]
        case .photo: return nil
        }
    }

    func image(for size: CGSize) -> UIImage? {
        switch self {
        case .none:
            return nil
        case .photo:
            guard let data = try? Data(contentsOf: Self.photoFileURL),
                  let image = UIImage(data: data) else { return nil }
            return image
        case .sunset, .ocean, .forest, .night:
            guard let colors = gradientColors else { return nil }
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = UIScreen.main.scale
            return UIGraphicsImageRenderer(size: size, format: format).image { context in
                let space = CGColorSpaceCreateDeviceRGB()
                guard let gradient = CGGradient(
                    colorsSpace: space,
                    colors: colors.map(\.cgColor) as CFArray,
                    locations: [0.0, 0.55, 1.0]
                ) else { return }
                let start = CGPoint(x: size.width / 2, y: 0)
                let end = CGPoint(x: size.width / 2, y: size.height)
                context.cgContext.drawLinearGradient(
                    gradient, start: start, end: end, options: [])
            }
        }
    }

    static func storePhoto(_ image: UIImage) {
        // Downscale to at most the screen's longest edge before writing —
        // a 48MP library photo would bloat Documents and slow every load.
        let maxEdge = max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
            * UIScreen.main.scale
        let target: UIImage
        if max(image.size.width, image.size.height) > maxEdge {
            let scale = maxEdge / max(image.size.width, image.size.height)
            let newSize = CGSize(width: image.size.width * scale,
                                 height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            target = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            target = image
        }
        try? target.pngData()?.write(to: photoFileURL, options: .atomic)
    }
}

/// Compact preset picker embedded in Settings → Appearance → 首页壁纸.
final class WallpaperPickerViewController: UITableViewController, PHPickerViewControllerDelegate {
    private var selected: Wallpaper {
        Wallpaper(rawValue: BrowserSettingsStore.shared.value.wallpaper) ?? .none
    }

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.tr("Home Wallpaper", "首页壁纸")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "WallpaperCell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? Wallpaper.allCases.count - 1 : 1  // presets | custom photo
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1
            ? L10n.tr("The photo stays on this device inside Vulpra's sandbox.",
                      "照片仅保存在本设备上，位于 Vulpra 的沙盒内。")
            : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "WallpaperCell", for: indexPath)
        let option = indexPath.section == 0 ? Wallpaper.allCases[indexPath.row] : .photo
        var content = cell.defaultContentConfiguration()
        content.text = option.displayName

        let sample = option.image(for: CGSize(width: 56, height: 56))
            ?? UIGraphicsImageRenderer(size: CGSize(width: 56, height: 56)).image { _ in
                UIColor.secondarySystemBackground.setFill()
                UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 56, height: 56), cornerRadius: 8).fill()
            }
        content.image = sample
        content.imageProperties.cornerRadius = 8
        cell.contentConfiguration = content
        cell.accessoryType = option == selected ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let option = Wallpaper.allCases[indexPath.row]
            BrowserSettingsStore.shared.update { $0.wallpaper = option.rawValue }
            NotificationCenter.default.post(name: .vulpraWallpaperDidChange, object: nil)
            tableView.reloadData()
        } else {
            presentPhotoPicker()
        }
    }

    private func presentPhotoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                Wallpaper.storePhoto(image)
                BrowserSettingsStore.shared.update { $0.wallpaper = Wallpaper.photo.rawValue }
                NotificationCenter.default.post(name: .vulpraWallpaperDidChange, object: nil)
                self?.tableView.reloadData()
            }
        }
    }
}

extension Notification.Name {
    static let vulpraWallpaperDidChange = Notification.Name("Vulpra.WallpaperDidChange")
}
