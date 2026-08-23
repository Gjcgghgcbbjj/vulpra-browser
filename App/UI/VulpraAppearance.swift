import UIKit

enum VulpraAppearance {
    /// Ember is deliberately used as a signal, never as a large surface color.
    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.48, blue: 0.35, alpha: 1)
            : UIColor(red: 0.89, green: 0.34, blue: 0.18, alpha: 1)
    }

    static let mutedAccent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.48, blue: 0.35, alpha: 0.16)
            : UIColor(red: 0.89, green: 0.34, blue: 0.18, alpha: 0.10)
    }

    static let cardFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 1, blue: 1, alpha: 0.07)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 0.72)
    }

    static let hairline = UIColor.separator.withAlphaComponent(0.38)

    static func applyGlobal() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithDefaultBackground()
        navigation.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        navigation.titleTextAttributes = [.foregroundColor: UIColor.label]
        navigation.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = accent

        let toolbar = UIToolbarAppearance()
        toolbar.configureWithDefaultBackground()
        toolbar.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        UIToolbar.appearance().standardAppearance = toolbar
        if #available(iOS 15.0, *) { UIToolbar.appearance().scrollEdgeAppearance = toolbar }

        UISwitch.appearance().onTintColor = accent
        UIProgressView.appearance().progressTintColor = accent
    }

    static func elevate(_ view: UIView, radius: CGFloat = 18, opacity: Float = 0.08) {
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = radius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = opacity
        view.layer.shadowRadius = 16
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.borderWidth = 1 / UIScreen.main.scale
        view.layer.borderColor = hairline.resolvedColor(with: view.traitCollection).cgColor
    }
}
