import Foundation
import GeckoView
import UIKit

RuntimeJITCoordinator.shared.start()
defer { RuntimeJITCoordinator.shared.stop() }
GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
