import UIKit

enum VulpraAppearance {
    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.72, blue: 1.0, alpha: 1)
            : UIColor(red: 0.05, green: 0.43, blue: 0.92, alpha: 1)
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
}
