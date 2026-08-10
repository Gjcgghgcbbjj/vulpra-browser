import Foundation
import os
import VulpraEngineKit

// Real-device JIT auto-enable (jailbreak route):
// Dopamine's "Allow JIT in Apps" marks the launched app process CS_DEBUGGED
// (0x800). When this process is debugged, forward the opt-in through the
// environment before the engine boots so GeckoChildProcessHost injects
// "-enable-jit" into every child XPC argv. The engine itself defaults to
// interpreter-only on real devices, so non-jailbroken installs stay
// unchanged (no CS_DEBUGGED -> no env -> interpreter).
#if !targetEnvironment(simulator)
@_silgen_name("csops")
private func vulpraCsops(_ pid: Int32, _ ops: UInt32,
                         _ useraddr: UnsafeMutableRawPointer?,
                         _ usersize: Int) -> Int32

private let vulpraJitLogger = Logger(subsystem: "com.vulpra.browser", category: "jit")

private func vulpraEnableJitIfEligible() {
    var flags: UInt32 = 0
    guard vulpraCsops(getpid(), 0 /* CS_OPS_STATUS */, &flags,
                      MemoryLayout<UInt32>.size) == 0 else {
        vulpraJitLogger.notice("Real-device JIT: csops status unavailable; interpreter-only")
        return
    }
    if flags & 0x800 /* CS_DEBUGGED */ != 0 {
        setenv("VULPRA_ENABLE_JIT", "1", 1)
        vulpraJitLogger.notice("Real-device JIT: process is CS_DEBUGGED; JIT enabled for engine children")
    } else {
        vulpraJitLogger.notice("Real-device JIT: not CS_DEBUGGED; interpreter-only")
    }
}
#endif

@discardableResult
func vulpraMain() -> Int32 {
#if !targetEnvironment(simulator)
    vulpraEnableJitIfEligible()
#endif
    return MainActor.assumeIsolated {
        VulpraEngineApplicationMain(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
    }
}

vulpraMain()
