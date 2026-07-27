import Foundation
import VulpraEngineKit

@discardableResult
func vulpraMain() -> Int32 {
    MainActor.assumeIsolated {
        VulpraEngineApplicationMain(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
    }
}

vulpraMain()
