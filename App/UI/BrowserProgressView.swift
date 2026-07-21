import UIKit

final class BrowserProgressView: UIProgressView {
    func update(progress: Int, loading: Bool, animated: Bool = true) {
        isHidden = false
        alpha = 1
        setProgress(Float(progress) / 100, animated: animated)
        guard !loading else { return }
        setProgress(1, animated: animated)
        UIView.animate(withDuration: 0.22, delay: 0.12, options: [.beginFromCurrentState]) {
            self.alpha = 0
        } completion: { _ in
            self.isHidden = true
            self.progress = 0
        }
    }
}
