import UIKit

/// One motion vocabulary for the whole shell. Every animation in the app goes
/// through here so springs feel related, and so Reduce Motion collapses them
/// to instant changes in a single place.
enum VulpraMotion {
    /// The standard interactive spring — controls, panels, entrances.
    static func spring(damping: CGFloat = 0.84,
                       duration: TimeInterval = 0.42,
                       _ changes: @escaping () -> Void) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            UIView.performWithoutAnimation(changes)
            return
        }
        UIView.animate(withDuration: duration, delay: 0,
                       usingSpringWithDamping: damping, initialSpringVelocity: 0.3,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: changes)
    }

    /// A softer settle for large surfaces (start page blocks, cards).
    static func settle(duration: TimeInterval = 0.34,
                       _ changes: @escaping () -> Void) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            UIView.performWithoutAnimation(changes)
            return
        }
        UIView.animate(withDuration: duration, delay: 0,
                       options: [.beginFromCurrentState, .curveEaseOut],
                       animations: changes)
    }

    /// Staggered entrance: fades and lifts each view in sequence.
    static func entrance(_ views: [UIView], baseOffset: CGFloat = 14, step: TimeInterval = 0.05) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        for (index, view) in views.enumerated() where !view.isHidden {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: baseOffset)
            UIView.animate(withDuration: 0.5,
                           delay: Double(index) * step,
                           usingSpringWithDamping: 0.9, initialSpringVelocity: 0.2,
                           options: [.beginFromCurrentState, .curveEaseOut]) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }
}
