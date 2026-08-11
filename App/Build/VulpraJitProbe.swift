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

    /// Two-line footer: main-app CS_DEBUGGED status plus the appex
    /// (Gecko child process) self-probe where JIT actually runs.
    static var footerText: String {
        "JIT: " + detail + "\n" + VulpraAppexProbe.summary()
    }
}

/// Reads the latest appex self-probe. The Vulpra Engine Process extension
/// (a Gecko child process instance - this is where web JS and the benchmark
/// actually run) writes this file at every launch:
///   {pid, processType, csops, flags, debugged, mapjit, mprotect, launches}
/// The App is no-sandbox in the TrollStore TIPA, so it can read the file the
/// appex published; sandboxed builds simply report "not-yet".
enum VulpraAppexProbe {
    static let paths = [
        "/var/mobile/Documents/vulpra-jit-probe.json",
        "/tmp/vulpra-jit-probe.json",
    ]

    static func summary() -> String {
        for path in paths {
            guard let data = FileManager.default.contents(atPath: path),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let flags = object["flags"] as? String ?? "?"
            let debugged = (object["debugged"] as? Bool).map { $0 ? "yes" : "NO" } ?? "?"
            let mapjit = object["mapjit"] as? String ?? "?"
            let mprotect = object["mprotect"] as? String ?? "?"
            let launches = object["launches"] as? Int ?? 0
            let pid = object["pid"] as? Int ?? 0
            var text = "appex: flags=\(flags) debugged=\(debugged) mapjit=\(mapjit) "
                + "mprotect=\(mprotect) launches=\(launches) pid=\(pid)"
            if launches >= 8 {
                text += "  ⚠可能循环重启"
            }
            return text
        }
        return "appex: 尚未启动（打开任意网页后再回来看）"
    }
}
