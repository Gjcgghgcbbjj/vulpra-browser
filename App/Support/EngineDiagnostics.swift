import Foundation
import GeckoView

/// One-shot engine self-check written to Documents so both the simulator CI
/// logs and device users (Files app, UIFileSharingEnabled) can read what the
/// engine ACTUALLY reports — no more guessing whether the UA pref landed.
/// The Settings page surfaces the same values for on-device triage.
enum EngineDiagnostics {
    static let expectedUA = BrowserSettings.spoofedUserAgent
    private static var ranOnce = false
    static private(set) var lastPrefAccepted: Bool?
    static private(set) var lastEngineUA: String?

    /// Idempotent — safe to call from sceneDidBecomeActive on every activation.
    static func run() {
        guard !ranOnce else { return }
        ranOnce = true
        probe()
    }

    /// Fresh measurement; updates the shared state Settings displays.
    static func probe(completion: (() -> Void)? = nil) {
        GeckoRuntime.setEngineStringPreference(
            name: "general.useragent.override",
            value: expectedUA
        ) { accepted in
            GeckoRuntime.queryEngineUserAgent { engineUA in
                lastPrefAccepted = accepted
                lastEngineUA = engineUA
                report(prefAccepted: accepted, engineUA: engineUA)
                completion?()
            }
        }
    }

    static var diagText: String {
        """
        === Vulpra engine diagnostics ===
        time: \(ISO8601DateFormatter().string(from: Date()))
        safariUAPrefAccepted: \(lastPrefAccepted.map { "\($0)" } ?? "<pending>")
        engineReportedUA: \(lastEngineUA ?? "<no answer>")
        engineMatchesSafari: \((lastEngineUA == expectedUA).description)
        expectedUA: \(expectedUA)
        """
    }

    private static func report(prefAccepted: Bool, engineUA: String?) {
        let matches = engineUA == expectedUA
        NSLog("VULPRA_DIAG safariUAPrefAccepted=%d", prefAccepted ? 1 : 0)
        NSLog("VULPRA_DIAG engineReportedUA=%@", engineUA ?? "<no answer>")
        NSLog("VULPRA_DIAG engineMatchesSafari=%d", matches ? 1 : 0)

        guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return }
        try? diagText.write(
            to: documents.appendingPathComponent("vulpra-engine-diag.txt"),
            atomically: true,
            encoding: .utf8
        )
    }
}
