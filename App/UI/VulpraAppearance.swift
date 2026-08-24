import UIKit

enum VulpraAppearance {
    /// Ember is deliberately used as a signal, never as a large surface color.
    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.48, blue: 0.35, alpha: 1)
            : UIColor(red: 0.89, green: 0.34, blue: 0.18, alpha: 1)
    }

    /// Warmer companion for gradients (ember → amber).
    static let accentAmber = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.66, blue: 0.42, alpha: 1)
            : UIColor(red: 0.96, green: 0.55, blue: 0.24, alpha: 1)
    }

    static var accentGradient: [CGColor] {
        [accent.cgColor, accentAmber.cgColor]
    }

    static let mutedAccent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.48, blue: 0.35, alpha: 0.16)
            : UIColor(red: 0.89, green: 0.34, blue: 0.18, alpha: 0.10)
    }

    /// Opaque elevated surface for cards and fields — crisp against the
    /// layered background, unlike translucent fills.
    static let surfaceElevated = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.13, blue: 0.14, alpha: 1)
            : UIColor.white
    }

    static let cardFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 1, blue: 1, alpha: 0.07)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 0.72)
    }

    static let hairline = UIColor.separator.withAlphaComponent(0.38)

    enum Radius {
        static let chip: CGFloat = 14
        static let card: CGFloat = 20
        static let field: CGFloat = 22
        /// Command bar: clearly rounded but not a pill.
        static let bar: CGFloat = 16
    }

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

    /// Ambient card elevation: soft wide warm-gray shadow + hairline edge.
    /// This pairing (not a bare border, not a heavy drop shadow) is what
    /// reads as "premium".
    static func elevate(_ view: UIView, radius: CGFloat = Radius.card, opacity: Float = 0.07) {
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = radius
        view.layer.shadowColor = UIColor(red: 0.35, green: 0.20, blue: 0.12, alpha: 1).cgColor
        view.layer.shadowOpacity = opacity
        view.layer.shadowRadius = 22
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.layer.borderWidth = 1 / UIScreen.main.scale
        view.layer.borderColor = hairline.resolvedColor(with: view.traitCollection).cgColor
    }

    /// Focus glow: a tight accent-tinted halo for the active field.
    static func applyFocusGlow(_ view: UIView, active: Bool) {
        view.layer.shadowColor = active ? accent.resolvedColor(with: view.traitCollection).cgColor
                                        : UIColor(red: 0.35, green: 0.20, blue: 0.12, alpha: 1).cgColor
        view.layer.shadowOpacity = active ? 0.26 : 0.07
        view.layer.shadowRadius = active ? 14 : 22
        view.layer.shadowOffset = CGSize(width: 0, height: active ? 4 : 10)
    }

    /// Small rounded logo mark used next to the wordmark.
    static func logoMark(size: CGFloat = 10) -> UIView {
        let mark = UIView()
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.layer.cornerCurve = .continuous
        mark.layer.cornerRadius = size * 0.32
        mark.backgroundColor = accent
        mark.isUserInteractionEnabled = false
        mark.widthAnchor.constraint(equalToConstant: size).isActive = true
        mark.heightAnchor.constraint(equalToConstant: size).isActive = true
        return mark
    }
}
