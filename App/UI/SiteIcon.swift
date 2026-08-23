import UIKit

/// Site icon pipeline shared by home grid and tab cards.
/// Real favicon (disk-cached) -> deterministic letter avatar -> never a bare
/// gray glyph. Letter-avatar palette + hashing follows the DuckDuckGo iOS
/// pattern; tile metrics follow firefox-ios TopSites (60pt, radius 16).
enum SiteIcon {
    static let tileSize = CGSize(width: 60, height: 60)
    static let tileCornerRadius: CGFloat = 16

    private static let palette: [UIColor] = [
        UIColor(red: 0.36, green: 0.54, blue: 0.98, alpha: 1), // blue
        UIColor(red: 0.35, green: 0.75, blue: 0.55, alpha: 1), // green
        UIColor(red: 0.96, green: 0.58, blue: 0.26, alpha: 1), // orange
        UIColor(red: 0.91, green: 0.40, blue: 0.46, alpha: 1), // red
        UIColor(red: 0.62, green: 0.47, blue: 0.89, alpha: 1), // purple
        UIColor(red: 0.28, green: 0.70, blue: 0.78, alpha: 1), // teal
        UIColor(red: 0.85, green: 0.62, blue: 0.24, alpha: 1), // gold
        UIColor(red: 0.58, green: 0.66, blue: 0.74, alpha: 1), // slate
    ]

    /// Stable per-host color so the same site always renders identically.
    private static func color(for host: String) -> UIColor {
        var hasher = UInt64(5381)
        for byte in host.utf8 { hasher = hasher &* 33 &+ UInt64(byte) }
        return palette[Int(hasher % UInt64(palette.count))]
    }

    /// Colored circle with the site's initial (DuckDuckGo favorites style).
    static func placeholder(for url: URL?, size: CGFloat = 48) -> UIImage {
        let rawHost = url?.host ?? ""
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        let letter = String((host.first ?? "g")).uppercased()
        let tint = color(for: host.isEmpty ? "vulpra" : host)
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { context in
            tint.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size * 0.44, weight: .semibold),
                .foregroundColor: UIColor.white,
            ]
            let text = NSAttributedString(string: letter, attributes: attributes)
            let bounds = text.boundingRect(
                with: CGSize(width: size, height: size),
                options: [.usesLineFragmentOrigin], context: nil)
            text.draw(at: CGPoint(x: (size - bounds.width) / 2,
                                  y: (size - bounds.height) / 2))
        }
    }

    /// Async favicon load with letter-avatar fallback baked in.
    static func load(for url: URL, completion: @escaping (UIImage) -> Void) {
        if let cached = FaviconStore.shared.cachedFavicon(for: url) {
            completion(cached)
            return
        }
        Task {
            guard let image = await FaviconStore.shared.favicon(for: url) else {
                await MainActor.run { completion(placeholder(for: url)) }
                return
            }
            await MainActor.run { completion(image) }
        }
    }

    /// Rounded square tile with the favicon aspect-FIT at its native size —
    /// tiny 16px favicons are never upscaled, so no mosaic blur. Falls back
    /// to the letter avatar when a site has no usable favicon.
    static func tile(for url: URL?, size: CGFloat, cornerRadius: CGFloat,
                      favicon: UIImage? = nil) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        return renderer.image { context in
            let host = url?.host ?? ""
            color(for: host.isEmpty ? "vulpra" : host).withAlphaComponent(0.16).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                         cornerRadius: cornerRadius).fill()
            guard let url else {
                placeholder(for: url, size: size)
                    .draw(in: CGRect(x: 0, y: 0, width: size, height: size))
                return
            }
            if let raw = favicon ?? FaviconStore.shared.cachedFavicon(for: url), raw.size.width > 1 {
                // Fit the favicon inside an inset box without ever enlarging it.
                let inset = size * 0.18
                let box = size - inset * 2
                var drawSize = raw.size
                if drawSize.width > box || drawSize.height > box {
                    let scale = min(box / drawSize.width, box / drawSize.height)
                    drawSize = CGSize(width: drawSize.width * scale, height: drawSize.height * scale)
                }
                let origin = CGPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)
                context.cgContext.interpolationQuality =
                    drawSize.width >= raw.size.width ? .high : .none
                raw.draw(in: CGRect(origin: origin, size: drawSize))
            } else {
                // Letter avatar centered on the tinted tile.
                placeholder(for: url, size: size)
                    .draw(in: CGRect(x: 0, y: 0, width: size, height: size))
            }
        }
    }
}
