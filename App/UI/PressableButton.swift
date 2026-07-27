import UIKit

final class PressableButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            UIView.animate(
                withDuration: isHighlighted ? 0.08 : 0.12, delay: 0,
                usingSpringWithDamping: 0.82, initialSpringVelocity: 0.25,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) { self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.94, y: 0.94) : .identity }
        }
    }

    convenience init(symbol: String, accessibilityLabel: String) {
        self.init(type: .system)
        setImage(UIImage(systemName: symbol), for: .normal)
        setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .regular), forImageIn: .normal)
        self.accessibilityLabel = accessibilityLabel
        tintColor = VulpraAppearance.graphite
        widthAnchor.constraint(equalToConstant: 44).isActive = true
        heightAnchor.constraint(equalToConstant: 44).isActive = true
    }
}
