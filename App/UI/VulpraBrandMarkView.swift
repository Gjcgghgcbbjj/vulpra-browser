import UIKit

final class VulpraBrandMarkView: UIView {
    private let graphiteLayer = CAShapeLayer()
    private let accentLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityLabel = "Vulpra"
        layer.addSublayer(graphiteLayer)
        layer.addSublayer(accentLayer)
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = min(bounds.width, bounds.height) / 56
        let offset = CGPoint(x: (bounds.width - 56 * scale) / 2, y: (bounds.height - 56 * scale) / 2)
        let transform = CGAffineTransform(translationX: offset.x, y: offset.y).scaledBy(x: scale, y: scale)

        let graphite = UIBezierPath()
        graphite.move(to: CGPoint(x: 8, y: 11))
        graphite.addLine(to: CGPoint(x: 20, y: 11))
        graphite.addLine(to: CGPoint(x: 28, y: 36))
        graphite.addLine(to: CGPoint(x: 37, y: 11))
        graphite.addLine(to: CGPoint(x: 48, y: 11))
        graphite.addLine(to: CGPoint(x: 31, y: 48))
        graphite.addCurve(to: CGPoint(x: 25, y: 48), controlPoint1: CGPoint(x: 30, y: 50), controlPoint2: CGPoint(x: 26, y: 50))
        graphite.close()
        graphite.apply(transform)
        graphiteLayer.path = graphite.cgPath

        let accent = UIBezierPath()
        accent.move(to: CGPoint(x: 34, y: 8))
        accent.addCurve(to: CGPoint(x: 46, y: 21), controlPoint1: CGPoint(x: 43, y: 10), controlPoint2: CGPoint(x: 47, y: 15))
        accent.addCurve(to: CGPoint(x: 35, y: 29), controlPoint1: CGPoint(x: 45, y: 27), controlPoint2: CGPoint(x: 40, y: 30))
        accent.addCurve(to: CGPoint(x: 34, y: 8), controlPoint1: CGPoint(x: 38, y: 21), controlPoint2: CGPoint(x: 37, y: 15))
        accent.close()
        accent.apply(transform)
        accentLayer.path = accent.cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }

    private func updateColors() {
        graphiteLayer.fillColor = VulpraAppearance.graphite.resolvedColor(with: traitCollection).cgColor
        accentLayer.fillColor = VulpraAppearance.accent.resolvedColor(with: traitCollection).cgColor
    }
}
