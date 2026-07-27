import UIKit

final class BrowserProgressView: UIProgressView {
    private var updateGeneration = 0

    func update(progress: Int, loading: Bool, animated: Bool = true) {
        updateGeneration &+= 1
        let generation = updateGeneration
        layer.removeAllAnimations()

        if !loading && progress == 0 {
            isHidden = true
            alpha = 0
            self.progress = 0
            return
        }

        isHidden = false
        alpha = 1
        setProgress(Float(progress) / 100, animated: animated)
        guard !loading else { return }
        setProgress(1, animated: animated)
        UIView.animate(withDuration: 0.16, delay: 0.12, options: [.beginFromCurrentState]) {
            self.alpha = 0
        } completion: { finished in
            guard finished, generation == self.updateGeneration else { return }
            self.isHidden = true
            self.progress = 0
        }
    }
}
