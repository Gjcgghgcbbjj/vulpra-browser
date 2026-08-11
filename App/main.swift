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
        VulpraJitProbe.detail = "csops-unavailable"
        vulpraJitLogger.notice("Real-device JIT: csops status unavailable; interpreter-only")
        return
    }
    // On-device iOS reports CS_DEBUGGED at bit 28 (0x10000000); classic
    // XNU cs_blobs.h places it at bit 11 (0x800). Accept either layout and
    // surface the raw flags so the effective bit is visible on the start page.
    let debuggedMask: UInt32 = 0x10000000 | 0x00000800
    if flags & debuggedMask != 0 {
        // v9 main-process JIT route: force e10s off so web JS runs in THIS
        // process, which Dopamine marked CS_DEBUGGED (verified on-device).
        // The packaged engine default pref (defaults/pref/vulpra-main-jit.js)
        // already flipped javascript.options.main_process_disable_jit=false,
        // so the main process's JS::Init keeps the JIT backend and MAP_JIT
        // succeeds in-process. No -enable-jit reaches children: with e10s off
        // there are no web content children, and auxiliary processes stay
        // interpreter-safe.
        setenv("MOZ_FORCE_DISABLE_E10S", "1", 1)
        VulpraJitProbe.mainProcessMode = true
        VulpraJitProbe.detail = String(
            format: "CS_DEBUGGED(主进程) 主进程JIT模式(e10s关) flags=0x%08X", flags)
        vulpraJitLogger.notice("Real-device JIT: main-process mode; e10s off, web JS in CS_DEBUGGED main process")
    } else {
        VulpraJitProbe.detail = String(format: "not-debugged (flags=0x%08X)", flags)
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
