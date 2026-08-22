import UIKit
import PhotosUI

// MARK: - Wallpaper options

/// Start-page wallpaper options. Preset gradients are rendered live by
/// `WallpaperView` through `CAGradientLayer` — nothing is rasterized into a
/// UIImage anywhere in this pipeline. That removes every size/scale failure
/// mode the previous renderer had: wrong bounds at first layout, screen-scale
/// math, gradient banding from fixed-size bitmaps, and nil images.
enum Wallpaper: String, CaseIterable {
    case none
    case sunset
    case ocean
    case forest
    case night
    case photo

    var displayName: String {
        switch self {
        case .none: return L10n.tr("None", "无")
        case .sunset: return L10n.tr("Sunset", "日落")
        case .ocean: return L10n.tr("Ocean", "海洋")
        case .forest: return L10n.tr("Forest", "森林")
        case .night: return L10n.tr("Night", "夜空")
        case .photo: return L10n.tr("Custom Photo", "自定义照片")
        }
    }

    /// True when start-page content should flip to dark semantics.
    /// `.photo` counts as dark so white text stays readable over arbitrary
    /// pictures unless the picture fails to load.
    var isDark: Bool {
        switch self {
        case .none: return false
        case .sunset, .ocean, .forest, .night, .photo: return true
        }
    }

    /// Four-stop diagonal palettes; GPU-interpolated by CAGradientLayer.
    var gradientColors: [CGColor]? {
        switch self {
        case .sunset:
            return [#colorLiteral(red: 1.00, green: 0.60, blue: 0.34, alpha: 1),
                    #colorLiteral(red: 1.00, green: 0.42, blue: 0.54, alpha: 1),
                    #colorLiteral(red: 0.77, green: 0.27, blue: 0.56, alpha: 1),
                    #colorLiteral(red: 0.36, green: 0.16, blue: 0.52, alpha: 1)].map(\.cgColor)
        case .ocean:
            return [#colorLiteral(red: 0.31, green: 0.76, blue: 0.97, alpha: 1),
                    #colorLiteral(red: 0.13, green: 0.59, blue: 0.95, alpha: 1),
                    #colorLiteral(red: 0.08, green: 0.40, blue: 0.75, alpha: 1),
                    #colorLiteral(red: 0.05, green: 0.23, blue: 0.40, alpha: 1)].map(\.cgColor)
        case .forest:
            return [#colorLiteral(red: 0.66, green: 0.88, blue: 0.39, alpha: 1),
                    #colorLiteral(red: 0.34, green: 0.67, blue: 0.18, alpha: 1),
                    #colorLiteral(red: 0.11, green: 0.59, blue: 0.42, alpha: 1),
                    #colorLiteral(red: 0.04, green: 0.24, blue: 0.18, alpha: 1)].map(\.cgColor)
        case .night:
            return [#colorLiteral(red: 0.21, green: 0.36, blue: 0.49, alpha: 1),
                    #colorLiteral(red: 0.17, green: 0.24, blue: 0.31, alpha: 1),
                    #colorLiteral(red: 0.10, green: 0.10, blue: 0.18, alpha: 1),
                    #colorLiteral(red: 0.06, green: 0.06, blue: 0.14, alpha: 1)].map(\.cgColor)
        case .none, .photo:
            return nil
        }
    }

    // MARK: Custom photo storage

    static let photoFileURL = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask
    )[0].appendingPathComponent("vulpra-wallpaper.png")

    private static var cachedPhoto: UIImage?

    /// Decoded photo, memory-cached; disk only touched once per launch.
    static func loadPhoto() -> UIImage? {
        if let cachedPhoto { return cachedPhoto }
        guard let data = try? Data(contentsOf: photoFileURL),
              let image = UIImage(data: data) else { return nil }
        cachedPhoto = image
        return image
    }

    /// Downscales past-device-pixel photos and stores atomically.
    /// Returns success so the picker can surface failures instead of them
    /// disappearing silently.
    @discardableResult
    static func storePhoto(_ image: UIImage) -> Bool {
        defer { cachedPhoto = image }
        let devicePixels = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * UIScreen.main.scale
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        let target: UIImage
        if longest > devicePixels {
            let ratio = devicePixels / longest
            let newSize = CGSize(width: image.size.width * ratio,
                                 height: image.size.height * ratio)
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            target = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            target = image
        }
        do {
            let data = target.pngData() ?? Data()
            try data.write(to: photoFileURL, options: .atomic)
            #if DEBUG
            NSLog("VULPRA_DIAG photo stored %d bytes", data.count)
            #endif
            return !data.isEmpty
        } catch {
            #if DEBUG
            NSLog("VULPRA_DIAG photo store FAILED: %@", error.localizedDescription)
            #endif
            return false
        }
    }

    /// Invalidate after overwriting the file so a fresh decode happens.
    static func invalidateCachedPhoto() { cachedPhoto = nil }
}

// MARK: - Backdrop view

/// Self-contained wallpaper backdrop. One gradient layer serves presets;
/// one content layer serves the custom photo. Both are laid out from
/// `bounds` on every layout pass, so rotation, first layout under
/// autoresizing containers, and any future size change just work.
final class WallpaperView: UIView {

    private let gradientLayer = CAGradientLayer()
    private let photoLayer = CALayer()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        clipsToBounds = true
        gradientLayer.startPoint = CGPoint(x: 0.15, y: 0.05)
        gradientLayer.endPoint = CGPoint(x: 0.85, y: 0.95)
        photoLayer.contentsGravity = .resizeAspectFill
        layer.addSublayer(gradientLayer)
        layer.addSublayer(photoLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        photoLayer.frame = bounds
        CATransaction.commit()
    }

    /// Idempotent; safe to call on every appearance.
    func apply(option: Wallpaper) {
        if let colors = option.gradientColors {
            gradientLayer.colors = colors
            gradientLayer.isHidden = false
        } else {
            gradientLayer.isHidden = true
        }

        if option == .photo, let cgImage = Wallpaper.loadPhoto()?.cgImage {
            photoLayer.contents = cgImage
            photoLayer.isHidden = false
        } else {
            photoLayer.contents = nil
            photoLayer.isHidden = true
        }

        // Visible iff something will actually draw. A picked-but-lost photo
        // degrades to the plain page instead of a black slab.
        isHidden = option == .none
            || (option.gradientColors == nil && photoLayer.isHidden)
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let vulpraWallpaperDidChange = Notification.Name("Vulpra.WallpaperDidChange")
}
