import UIKit

final class PressableButton: UIButton {
    override var isHighlighted: Bool {
        didSet {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            UIView.animate(
                withDuration: 0.18, delay: 0,
                usingSpringWithDamping: 0.72, initialSpringVelocity: 0.4,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) { self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.88, y: 0.88) : .identity }
        }
    }

    convenience init(symbol: String, accessibilityLabel: String) {
        self.init(type: .system)
        setImage(UIImage(systemName: symbol), for: .normal)
        self.accessibilityLabel = accessibilityLabel
        tintColor = .label
        widthAnchor.constraint(equalToConstant: 42).isActive = true
        heightAnchor.constraint(equalToConstant: 42).isActive = true
    }
}
