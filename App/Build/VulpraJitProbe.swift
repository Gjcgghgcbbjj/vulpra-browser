import Foundation

/// Real-device JIT eligibility captured once at process launch (main.swift)
/// before the engine boots. The start page renders this so the state is
/// visible on-device without any shell access:
///   - "CS_DEBUGGED": Dopamine marked this process debugged; env was set and
///     engine children receive -enable-jit.
///   - "not-debugged": no CS_DEBUGGED; interpreter-only default kept.
///   - "csops-unavailable": the probe itself failed; interpreter-only.
enum VulpraJitProbe {
    static var detail = "unknown"
}
