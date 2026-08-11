import Foundation
import Darwin

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
        let (object, _) = VulpraAppexProbe.readProbe()
        guard let object else { return false }
        let mapjit = object["mapjit"] as? String ?? ""
        let mprotect = object["mprotect"] as? String ?? ""
        return mapjit == "ok" && mprotect == "ok"
    }

    /// Human-readable reason for staying interpreter-only while the main
    /// process itself is CS_DEBUGGED (rendered in the start-page footer).
    static var interpreterReason: String {
        let (object, _) = VulpraAppexProbe.readProbe()
        guard let object else {
            return "appex探针未就绪(首启解释器,重启后自动评估JIT)"
        }
        let mapjit = object["mapjit"] as? String ?? ""
        let mprotect = object["mprotect"] as? String ?? ""
        return "appex无法JIT(mapjit=\(mapjit) mprotect=\(mprotect))"
    }

    /// Two-line footer: main-app CS_DEBUGGED status plus either the appex
    /// (Gecko child process) self-probe or the main-process mode note.
    static var footerText: String {
        let selftest = " 自检:" + VulpraAppexProbe.selfTest()
        if mainProcessMode {
            return "JIT: " + detail + selftest
                + "\n主进程模式：网页JS跑在主App进程(CS_DEBUGGED已确认)，appex不参与"
        }
        return "JIT: " + detail + selftest + "\n" + VulpraAppexProbe.summary()
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
    static let appexBundleID = "com.vulpra.browser.engine-process"

    /// All read channels, in priority order: shared /var paths, then the
    /// appex's own container Documents (found via container metadata scan).
    static func allChannels() -> [(path: String, label: String)] {
        var channels = paths.map { ($0, $0) }
        if let container = findAppexContainer() {
            channels.append((container + "/Documents/vulpra-jit-probe.json", "容器"))
        }
        return channels
    }

    /// Locate the appex data container by scanning container metadata. Both
    /// the App and the appex are no-sandbox in the TrollStore TIPA, so the
    /// App can enumerate /var/mobile/Containers and match the bundle id.
    static func findAppexContainer() -> String? {
        let root = "/var/mobile/Containers/Data/Application"
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: root) else {
            return nil
        }
        for entry in entries {
            let dir = root + "/" + entry
            let metadata = dir + "/.com.apple.mobile_container_manager.metadata.plist"
            guard let data = FileManager.default.contents(atPath: metadata),
                  let plist = try? PropertyListSerialization.propertyList(
                      from: data, options: [], format: nil) as? [String: Any],
                  (plist["MCMMetadataIdentifier"] as? String) == appexBundleID else {
                continue
            }
            return dir
        }
        return nil
    }

    /// Read the newest probe from every channel; returns the first hit plus
    /// the channel label that produced it.
    static func readProbe() -> (object: [String: Any]?, source: String) {
        for (path, label) in allChannels() {
            guard let data = FileManager.default.contents(atPath: path),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            return (object, label)
        }
        return (nil, "")
    }

    static func summary() -> String {
        let (object, source) = readProbe()
        if let object {
            let flags = object["flags"] as? String ?? "?"
            let debugged = (object["debugged"] as? Bool).map { $0 ? "yes" : "NO" } ?? "?"
            let mapjit = object["mapjit"] as? String ?? "?"
            let mprotect = object["mprotect"] as? String ?? "?"
            let launches = object["launches"] as? Int ?? 0
            let pid = object["pid"] as? Int ?? 0
            let writePrimary = object["writePrimary"] as? String ?? "?"
            let writeFallback = object["writeFallback"] as? String ?? "?"
            let writeOwn = object["writeOwnContainer"] as? String ?? "?"
            var text = "appex: flags=\(flags) debugged=\(debugged) mapjit=\(mapjit) "
                + "mprotect=\(mprotect) launches=\(launches) pid=\(pid)"
                + " [写:\(writePrimary)/\(writeFallback)/\(writeOwn) 读自:\(source)]"
            if launches >= 8 {
                text += "  ⚠可能循环重启"
            }
            return text
        }
        return "appex: 尚无(通道:" + channelStatus() + ")"
    }

    /// Per-channel existence status for diagnosis when no probe is readable.
    static func channelStatus() -> String {
        var parts: [String] = []
        for (path, label) in allChannels() {
            parts.append(FileManager.default.fileExists(atPath: path)
                         ? label + "=在" : label + "=缺")
        }
        return parts.joined(separator: " ")
    }

    /// App-side write/read self-test on the shared /var paths. Proves whether
    /// the shared-file channel works at all from the App process (both the
    /// App and the appex are no-sandbox in the TrollStore TIPA).
    static func selfTest() -> String {
        let stamp = "vulpra-self-\(getpid())-\(Int(Date().timeIntervalSince1970))"
        var parts: [String] = []
        for dir in ["/var/mobile/Documents", "/tmp"] {
            let file = dir + "/vulpra-app-self-test.txt"
            do {
                try stamp.write(toFile: file, atomically: true, encoding: .utf8)
                let read = try? String(contentsOfFile: file, encoding: .utf8)
                parts.append("\(dir)=\(read == stamp ? "ok" : "mismatch")")
            } catch {
                parts.append("\(dir)=err\((error as NSError).code)")
            }
        }
        return parts.joined(separator: " ")
    }
}
