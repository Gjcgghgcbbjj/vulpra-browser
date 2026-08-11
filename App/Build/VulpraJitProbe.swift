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

    /// True when the App runs web JS in the main process (v9: e10s forced
    /// off under CS_DEBUGGED). In that mode the appex is not a web content
    /// host, so the footer's second line describes the mode instead of the
    /// (dormant) appex probe.
    static var mainProcessMode = false

    /// Adaptive mode decision (read once at launch): JIT is enabled only when
    /// a recent appex self-probe positively proves this device can allocate
    /// executable JIT memory (mmap(MAP_JIT) AND the RX reprotect both "ok").
    /// With no probe yet (first launch after install/upgrade, or the file was
    /// wiped) the App stays in interpreter mode, so a JIT-enabled content
    /// process can never crash-loop the browser into "unusable" lag. The probe
    /// file is rewritten by every appex launch, so once the appex proves
    /// capable the next App launch re-enables JIT automatically.
    static func appexJITAvailable() -> Bool {
        for path in VulpraAppexProbe.paths {
            guard let data = FileManager.default.contents(atPath: path),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let mapjit = object["mapjit"] as? String ?? ""
            let mprotect = object["mprotect"] as? String ?? ""
            if mapjit == "ok" && mprotect == "ok" {
                return true
            }
        }
        return false
    }

    /// Human-readable reason for staying interpreter-only while the main
    /// process itself is CS_DEBUGGED (rendered in the start-page footer).
    static var interpreterReason: String {
        for path in VulpraAppexProbe.paths {
            guard let data = FileManager.default.contents(atPath: path),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let mapjit = object["mapjit"] as? String ?? ""
            let mprotect = object["mprotect"] as? String ?? ""
            if mapjit != "ok" || mprotect != "ok" {
                return "appex无法JIT(mapjit=\(mapjit) mprotect=\(mprotect))"
            }
        }
        return "appex探针未就绪(首启解释器,重启后自动评估JIT)"
    }

    /// Two-line footer: main-app CS_DEBUGGED status plus either the appex
    /// (Gecko child process) self-probe or the main-process mode note.
    static var footerText: String {
        if mainProcessMode {
            return "JIT: " + detail
                + "\n主进程模式：网页JS跑在主App进程(CS_DEBUGGED已确认)，appex不参与"
        }
        return "JIT: " + detail + "\n" + VulpraAppexProbe.summary()
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
