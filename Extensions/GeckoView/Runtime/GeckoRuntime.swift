//
//  GeckoRuntime.swift
//  Reynard
//
//  Created by Minh Ton on 1/2/26.
//

import Foundation
import UIKit

class GeckoRuntimeImpl: NSObject, SwiftGeckoViewRuntime {
    func runtimeDispatcher() -> any SwiftEventDispatcher {
        return GeckoEventDispatcherWrapper.runtimeInstance
    }

    func dispatcher(byName name: UnsafePointer<CChar>!) -> any SwiftEventDispatcher {
        return GeckoEventDispatcherWrapper.lookup(byName: String(cString: name))
    }

    @objc(childProcessDidStartWithPID:processType:)
    func childProcessDidStart(withPID pid: Int32, processType: String) {
        // Bounded per-child ceiling (not the main-process share) so one runaway
        // tab cannot starve the system; a child that exceeds it dies alone and
        // Gecko restarts just that content process.
        updateJetsamControlForChild(pid)

        NotificationCenter.default.post(
            name: Notification.Name("GeckoRuntime.ChildProcessDidStart"),
            object: nil,
            userInfo: [
                "pid": NSNumber(value: pid),
                "processType": processType
            ]
        )
    }
}

public class GeckoRuntime {
    static let runtime = GeckoRuntimeImpl()

    public static var version: String {
        return GeckoRuntimeBridge.version()
    }

    public static func setLocale(acceptLanguages: String) {
        let languages = acceptLanguages
        GeckoEngineGate.whenReady {
            GeckoEventDispatcherWrapper.runtimeInstance.dispatch(
                type: "GeckoView:SetLocale",
                message: [
                    "acceptLanguages": languages
                ]
            )
        }
    }

    /// Set a live engine preference through the privileged preferences channel
    /// (GeckoViewPreferences in the main process). Runs after the engine gate
    /// opens; the dispatcher queues the call if the native side is not yet up.
    public static func setEngineStringPreference(name: String, value: String) {
        GeckoEngineGate.whenReady {
            // PREF_STRING = Ci.nsIPrefBranch.PREF_STRING; branch "user" so the
            // value lands on the user branch, not the default branch.
            Task {
                _ = try? await GeckoEventDispatcherWrapper.runtimeInstance.query(
                    type: "GeckoView:Preferences:SetPref",
                    message: [
                        "prefs": [
                            ["pref": name, "type": 32, "value": value, "branch": "user"]
                        ]
                    ]
                )
            }
        }
    }

    public static func main(
        argc: Int32,
        argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>
    ) {
        MainProcessInit(argc, argv, runtime)
    }

    public static func childMain(
        xpcConnection: xpc_connection_t,
        process: GeckoProcessExtension
    ) {
        ChildProcessInit(xpcConnection, process, runtime)
    }
}
