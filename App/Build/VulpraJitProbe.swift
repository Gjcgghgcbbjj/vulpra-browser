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

    /// True when the App runs web JS in the main process (v9 experiment:
    /// e10s forced off under CS_DEBUGGED). v11 reverted the main-process
    /// route (it crashed on-device); the flag is kept so the footer can still
    /// render the main-process note if a future build re-enables it.
    static var mainProcessMode = false

    /// Startup-path JIT gate: reads ONLY the shared probe paths, exactly like
    /// v8. The launch path never touches container scanning or self-test
    /// writes - those run only from the start-page footer (cached), so a
    /// filesystem/entitlement surprise there can never crash the App at boot.
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
    /// (Gecko child process) self-probe or the main-process mode note, plus
    /// cached App-side self-test and any crash breadcrumb.
    static var footerText: String {
        let selftest = " 自检:" + VulpraAppexProbe.selfTest()
        var text: String
        if mainProcessMode {
            text = "JIT: " + detail + selftest
                + "\n主进程模式：网页JS跑在主App进程(CS_DEBUGGED已确认)，appex不参与"
        } else {
            text = "JIT: " + detail + selftest + "\n" + VulpraAppexProbe.summary()
        }
        if let crash = VulpraCrashReporter.lastCrashSummary() {
            text += "\n⚠上次崩溃: " + crash
        }
        return text
    }
}

/// Reads the latest appex self-probe. The Vulpra Engine Process extension
/// (a Gecko child process instance - this is where web JS and the benchmark
/// actually run) writes this file at every launch:
///   {pid, processType, csops, flags, debugged, mapjit, mprotect, launches,
///    writePrimary, writeFallback, writeOwnContainer, ownContainerPath}
/// The App is no-sandbox in the TrollStore TIPA, so it can read the file the
/// appex published; sandboxed builds simply report "not-yet".
enum VulpraAppexProbe {
    static let paths = [
        "/var/mobile/Documents/vulpra-jit-probe.json",
        "/tmp/vulpra-jit-probe.json",
    ]
    static let appexBundleID = "com.vulpra.browser.engine-process"

    /// All read channels, in priority order: shared /var paths, then the
    /// appex's own container Documents (found via container metadata scan,
    /// which is cached after the first call).
    static func allChannels() -> [(path: String, label: String)] {
        var channels = paths.map { ($0, $0) }
        if let container = findAppexContainer() {
            channels.append((container + "/Documents/vulpra-jit-probe.json", "容器"))
        }
        return channels
    }

    private static var cachedContainer: String?
    private static var containerScanned = false

    /// Locate the appex data container by scanning container metadata. Both
    /// the App and the appex are no-sandbox in the TrollStore TIPA, so the
    /// App can enumerate /var/mobile/Containers and match the bundle id.
    /// Result is cached: footer refresh must never re-scan the whole tree.
    static func findAppexContainer() -> String? {
        if containerScanned { return cachedContainer }
        cachedContainer = scanAppexContainer()
        containerScanned = true
        return cachedContainer
    }

    private static func scanAppexContainer() -> String? {
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

    private static var cachedSelfTest = "pending"
    private static var selfTestScheduled = false

    /// App-side write/read self-test on the shared /var paths, computed once
    /// and refreshed in the background. Proves whether the shared-file
    /// channel works at all from the App process (both the App and the appex
    /// are no-sandbox in the TrollStore TIPA). Never runs on the footer's
    /// main-thread refresh after the first render.
    static func selfTest() -> String {
        if selfTestScheduled { return cachedSelfTest }
        selfTestScheduled = true
        cachedSelfTest = runSelfTest()
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            cachedSelfTest = runSelfTest()
        }
        return cachedSelfTest
    }

    private static func runSelfTest() -> String {
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

/// Minimal crash breadcrumbs so a future on-device crash can be diagnosed
/// without any shell access. The signal path uses a pre-opened file
/// descriptor and POSIX write()/snprintf() only (async-signal-safe enough
/// for diagnostics); the uncaught-exception path may use Foundation because
/// it does not run inside a signal handler.
enum VulpraCrashReporter {
    static let sharedPath = "/var/mobile/Documents/vulpra-crash.json"
    private static var signalFD: Int32 = -1
    private static let lock = NSLock()

    static func install() {
        lock.lock()
        defer { lock.unlock() }
        guard signalFD < 0 else { return }
        signalFD = sharedPath.withCString {
            open($0, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        }
        NSSetUncaughtExceptionHandler(vulpraCrashExceptionHandler)
        // Force eager initialization of the breadcrumb arrays in normal
        // context so the signal handler never allocates.
        _ = msgAbort; _ = msgBus; _ = msgFpe; _ = msgIll; _ = msgSegv; _ = msgTrap; _ = msgOther
        signal(SIGABRT, crashHandler)
        signal(SIGBUS, crashHandler)
        signal(SIGFPE, crashHandler)
        signal(SIGILL, crashHandler)
        signal(SIGSEGV, crashHandler)
        signal(SIGTRAP, crashHandler)
    }

    // Pre-formatted breadcrumbs (UTF-8, NUL-terminated). Touched in install()
    // so they are initialized in normal context; the signal handler only
    // reads them and writes bytes - no allocation, no variadic C calls.
    private static let msgAbort: [CChar] = Array("{\"type\":\"signal\",\"signal\":6}\n".utf8CString)
    private static let msgBus: [CChar] = Array("{\"type\":\"signal\",\"signal\":10}\n".utf8CString)
    private static let msgFpe: [CChar] = Array("{\"type\":\"signal\",\"signal\":8}\n".utf8CString)
    private static let msgIll: [CChar] = Array("{\"type\":\"signal\",\"signal\":4}\n".utf8CString)
    private static let msgSegv: [CChar] = Array("{\"type\":\"signal\",\"signal\":11}\n".utf8CString)
    private static let msgTrap: [CChar] = Array("{\"type\":\"signal\",\"signal\":5}\n".utf8CString)
    private static let msgOther: [CChar] = Array("{\"type\":\"signal\",\"signal\":0}\n".utf8CString)

    private static let crashHandler: @convention(c) (Int32) -> Void = { sig in
        let msg: [CChar]
        switch sig {
        case SIGABRT: msg = VulpraCrashReporter.msgAbort
        case SIGBUS: msg = VulpraCrashReporter.msgBus
        case SIGFPE: msg = VulpraCrashReporter.msgFpe
        case SIGILL: msg = VulpraCrashReporter.msgIll
        case SIGSEGV: msg = VulpraCrashReporter.msgSegv
        case SIGTRAP: msg = VulpraCrashReporter.msgTrap
        default: msg = VulpraCrashReporter.msgOther
        }
        let len = msg.count - 1  // strip the trailing NUL
        if signalFD >= 0 {
            _ = write(signalFD, msg, len)
        }
        _ = write(2, msg, len)
        signal(sig, SIG_DFL)
        raise(sig)
    }

    /// One-line summary of the last crash recorded on this device, or nil.
    static func lastCrashSummary() -> String? {
        guard let data = FileManager.default.contents(atPath: sharedPath),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if (object["type"] as? String) == "signal", let sig = object["signal"] as? Int {
            return "signal(\(sig))"
        }
        if (object["type"] as? String) == "exception" {
            let name = object["name"] as? String ?? "?"
            let reason = object["reason"] as? String ?? ""
            return "exception \(name): \(reason)"
        }
        return nil
    }
}

/// Global (non-capturing) handler for NSSetUncaughtExceptionHandler: a C
/// function pointer cannot be formed from a capturing closure.
private func vulpraCrashExceptionHandler(_ exception: NSException) {
    let text = "{\"type\":\"exception\",\"name\":\"\(exception.name.rawValue)\","
        + "\"reason\":\"\(exception.reason ?? "")\"}"
    try? text.write(toFile: VulpraCrashReporter.sharedPath, atomically: true, encoding: .utf8)
}
