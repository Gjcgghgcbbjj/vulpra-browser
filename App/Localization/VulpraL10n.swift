import Foundation
import VulpraEngineKit

enum VulpraL10n {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
    }

    static func text(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: .main, value: fallback, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }
}

extension DownloadRecord.State {
    var localizedTitle: String { VulpraL10n.text("downloads.state.\(rawValue)") }
}

extension TrackingProtectionLevel {
    var localizedTitle: String { VulpraL10n.text("tracking.\(rawValue)") }
}

extension SitePermissionRecord.Decision {
    var localizedTitle: String { VulpraL10n.text("permission.decision.\(rawValue)") }
}

extension EnginePermissionKind {
    var localizedTitle: String { VulpraL10n.text("permission.kind.\(rawValue)") }
}
