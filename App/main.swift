import Foundation
import GeckoView
import UIKit
import Darwin

#if VULPRA_DIAGNOSTIC
let diagnosticWindow = UIWindow(frame: UIScreen.main.bounds)
diagnosticWindow.rootViewController = UIViewController()
diagnosticWindow.backgroundColor = .systemBackground
diagnosticWindow.makeKeyAndVisible()
#elseif VULPRA_GECKO_LOAD_DIAGNOSTIC
let diagnosticWindow = UIWindow(frame: UIScreen.main.bounds)
diagnosticWindow.rootViewController = UIViewController()
diagnosticWindow.backgroundColor = .systemBackground
diagnosticWindow.makeKeyAndVisible()
_ = GeckoRuntime.version
#else
/// Append a single line to Caches/vulpra-startup.log for device crash triage.
func vulpraStartupMarker(_ value: String) {
    let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("vulpra-startup.log")
    let line = "\(Date().timeIntervalSince1970) \(value)\n"
    if let data = line.data(using: .utf8),
       let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }
}

/// iOS 13 + no-sandbox only (exact Reynard gate).
/// On iOS 14+ TrollStore, Gecko must keep the normal container layout;
/// forcing MOZ_APP_DATA into Caches there can break MainProcessInit.
@available(iOS, introduced: 13.0, obsoleted: 14.0)
private func configureUnsandboxedAppDataDirectories() {
    guard
        let cachesDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first,
        let bundleIdentifier = Bundle.main.bundleIdentifier
    else {
        return
    }

    let appDataDirectory = cachesDirectory
        .appendingPathComponent(bundleIdentifier, isDirectory: true)
        .appendingPathComponent(".mozilla", isDirectory: true)
        .appendingPathComponent("firefox", isDirectory: true)

    do {
        try FileManager.default.createDirectory(
            at: appDataDirectory,
            withIntermediateDirectories: true
        )
    } catch {
        return
    }

    setenv("MOZ_APP_DATA", appDataDirectory.path, 1)
    setenv("MOZ_LOCAL_APP_DATA", appDataDirectory.path, 1)
}

/// Raise the jetsam ceiling for the main process before Gecko allocates.
private func prepareMainProcessMemoryBudget() {
    updateJetsamControl(getpid())
}

// Startup order matches the working Reynard client:
// markers → optional iOS-13 profile paths → JIT observer → Gecko owns the process.
// Never defer-stop the JIT coordinator around engine main.
vulpraStartupMarker("main-enter")
prepareMainProcessMemoryBudget()
vulpraStartupMarker("jetsam-configured")
if #unavailable(iOS 14.0),
   getEntitlementValue("com.apple.private.security.no-sandbox") {
    configureUnsandboxedAppDataDirectories()
    vulpraStartupMarker("profile-configured-ios13")
} else {
    vulpraStartupMarker("profile-default-container")
}
#if !VULPRA_DISABLE_STARTUP_JIT
RuntimeJITCoordinator.shared.start()
vulpraStartupMarker("jit-started")
#endif
vulpraStartupMarker("gecko-main-enter")
GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
#endif
