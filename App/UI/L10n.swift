import Foundation

/// Minimal dual-language helper: picks Chinese strings when the system runs
/// in Chinese, otherwise falls back to English. Kept dependency-free on
/// purpose — no .strings tables, just paired literals at call sites.
enum L10n {
    static var isChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
    }

    static func tr(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }
}
