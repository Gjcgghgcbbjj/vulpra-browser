import Foundation
import GeckoView
import UIKit

func vulpraStartupMarker(_ value: String) {
    let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("vulpra-startup.log")
    let line = "\(Date().timeIntervalSince1970) \(value)\n"
    if let data = line.data(using: .utf8),
       let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile(); handle.write(data); try? handle.close()
    } else {
        try? line.write(to: url, atomically: true, encoding: .utf8)
    }
}

vulpraStartupMarker("main-enter")
RuntimeJITCoordinator.shared.start()
vulpraStartupMarker("jit-started")
defer { RuntimeJITCoordinator.shared.stop() }
vulpraStartupMarker("gecko-main-enter")
GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
