import UIKit

enum VulpraAppearance {
    static let porcelain = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
            : UIColor(red: 0.97, green: 0.973, blue: 0.965, alpha: 1)
    }

    static let graphite = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.94, blue: 0.93, alpha: 1)
            : UIColor(red: 0.141, green: 0.153, blue: 0.169, alpha: 1)
    }

    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.48, blue: 0.39, alpha: 1)
            : UIColor(red: 0.91, green: 0.365, blue: 0.271, alpha: 1)
    }

    static let privateAccent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.33, green: 0.73, blue: 0.68, alpha: 1)
            : UIColor(red: 0.176, green: 0.549, blue: 0.51, alpha: 1)
    }

    static let separator = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.12)
            : UIColor(red: 0.894, green: 0.906, blue: 0.918, alpha: 1)
    }

    static let dockRadius: CGFloat = 12
    static let itemRadius: CGFloat = 8

    static func applyGlobal() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithDefaultBackground()
        navigation.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        navigation.shadowColor = separator
        navigation.titleTextAttributes = [.foregroundColor: UIColor.label]
        navigation.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = accent

        let toolbar = UIToolbarAppearance()
        toolbar.configureWithDefaultBackground()
        toolbar.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        toolbar.shadowColor = separator
        UIToolbar.appearance().standardAppearance = toolbar
        if #available(iOS 15.0, *) { UIToolbar.appearance().scrollEdgeAppearance = toolbar }

        UISwitch.appearance().onTintColor = accent
        UIProgressView.appearance().progressTintColor = accent
    }
}
