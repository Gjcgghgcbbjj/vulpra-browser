import Foundation

/// Minimal dual-language helper. Vulpra ships Chinese-first per product
/// decision: every user-facing string resolves to the Chinese variant, with
/// the English literal kept inline as documentation and future fallback.
enum L10n {
    static func tr(_ en: String, _ zh: String) -> String {
        zh
    }
}
