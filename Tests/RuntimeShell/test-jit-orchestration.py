#!/usr/bin/env python3
"""Verify the exactly-once Gecko child JIT readiness owner."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
COORDINATOR = ROOT / "App" / "RuntimeJITCoordinator.swift"
BRIDGE = ROOT / "App" / "Bridging" / "Vulpra-Bridging-Header.h"
GECKO_HEADER = ROOT / "Extensions" / "GeckoView" / "View" / "GeckoView.h"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def quoted_imports(path: Path) -> list[str]:
    return re.findall(r'^\s*#import\s+"([^"]+)"', path.read_text(encoding="utf-8"), re.M)


def require_header_closure(path: Path) -> None:
    headers = list(ROOT.rglob("*.h"))
    for imported in quoted_imports(path):
        local = path.parent / imported
        matches = [candidate for candidate in headers if candidate.name == Path(imported).name]
        require(local.is_file() or len(matches) == 1, f"unresolved quoted header {imported} from {path.relative_to(ROOT)}")


def main() -> None:
    if not COORDINATOR.is_file():
        fail("missing App/RuntimeJITCoordinator.swift")
    require(BRIDGE.is_file(), "missing App/Bridging/Vulpra-Bridging-Header.h")
    require(GECKO_HEADER.is_file(), "missing GeckoView.h")

    source = COORDINATOR.read_text(encoding="utf-8")
    require(len(source.splitlines()) < 220, "RuntimeJITCoordinator exceeds 220-line budget")
    require("static let shared = RuntimeJITCoordinator()" in source, "missing single coordinator instance")
    require(len(re.findall(r"DispatchQueue\s*\(", source)) == 2, "coordinator must own exactly two queues")
    require("private let attachQueue" in source, "missing attach queue")
    require("private let stateQueue" in source, "missing state queue")
    # Phase 3: the 4.5s deadline was removed — it raced the child's 5s poll
    # and misreported slow-but-succeeding attaches as failures.
    require("deadline: .now() + 4.5" not in source, "JIT 4.5s deadline must be removed (races child poll)")
    require('Notification.Name("GeckoRuntime.ChildProcessDidStart")' in source, "wrong Gecko notification")
    require("private var pendingPIDs: Set<Int32>" in source, "missing pending PID owner")
    require("private var completedPIDs: Set<Int32>" in source, "missing completed PID suppression")
    require("pendingPIDs.contains(pid)" in source and "completedPIDs.contains(pid)" in source, "duplicate PID suppression is incomplete")
    require("guard pid > 0" in source, "positive PID validation is missing")
    require("trimmingCharacters(in: .whitespacesAndNewlines).lowercased()" in source, "process type normalization is missing")
    require('processType == "tab"' in source, "only tab children may attach")
    # Phase 1: hasTXMSupport is now derived from OS version, not hardcoded.
    require("version.majorVersion >= 26" in source, "TXM support must be detected from OS major version >= 26")
    require("hasTXMSupport: 0" not in source, "hasTXMSupport must not be hardcoded to 0")
    require("enableJIT(forPID: pid, hasTXMSupport: false)" not in source, "enableJIT must not hardcode hasTXMSupport: false")
    require("let txm = runtimeInfo().hasTXMSupport" in source, "enableJIT must receive real TXM from runtimeInfo")

    finish = re.search(
        r"private func finish\(pid: Int32, enabled: Bool, reason: String\) \{(?P<body>.*?)\n    \}",
        source,
        re.S,
    )
    require(finish is not None, "missing canonical finish function")
    finish_body = finish.group("body")
    removal = finish_body.find("pendingPIDs.remove(pid)")
    report = finish_body.find("ReportJITStatusForChild")
    require(removal >= 0 and report > removal, "pending PID must be removed before reporting")
    require(finish_body.count("ReportJITStatusForChild") == 1, "finish must report exactly once")

    for contract in (
        "finish(pid: pid, enabled: false, reason: \"non-tab\")",
        "finish(pid: pid, enabled: false, reason: \"attachment-failed\")",
        "finish(pid: pid, enabled: true, reason: \"attached\")",
        "for pid in pending",
        "finish(pid: pid, enabled: false, reason: \"teardown\")",
        "JITEnabler.shared.detachAllJITSessions()",
        "NotificationCenter.default.removeObserver(observer)",
    ):
        require(contract in source, f"missing JIT orchestration contract: {contract}")

    # Phase 4: the no-sandbox short-circuit was removed — non-TrollStore
    # sideloads must reach JITEnabler.enableJIT so RPPairing can run.
    for forbidden_contract in (
        'finish(pid: pid, enabled: false, reason: "deadline")',
        'finish(pid: pid, enabled: false, reason: "no-unsandboxed-entitlement")',
        "usesUnsandboxedPtrace",
    ):
        require(forbidden_contract not in source, f"removed old short-circuit contract must not remain: {forbidden_contract}")

    for forbidden in (
        "JITController",
        "Prefs",
        "Retry",
        "retry",
        "Diagnostics",
        "FailureView",
        "UIAlertController",
        "UserDefaults",
        "hasTXMSupport()",
    ):
        require(forbidden not in source, f"coordinator contains excluded policy/UI token: {forbidden}")

    bridge = BRIDGE.read_text(encoding="utf-8")
    for header in ("JITEnabler.h", "Utils.h", "IOSBootstrap.h"):
        require(header in bridge, f"bridge missing {header}")
    for forbidden in (
        "UIKit+Private.h",
        "TSUtils.h",
        "JITController",
        "ExtensionBridge.h",
        "GeckoRuntimeBridge.h",
    ):
        require(forbidden not in bridge, f"bridge contains forbidden header: {forbidden}")

    gecko_header = GECKO_HEADER.read_text(encoding="utf-8")
    require("TSUtils.h" not in gecko_header, "stale TSUtils.h import remains")
    require(
        "<GeckoView/GeckoViewSwiftSupport.h>" in gecko_header,
        "framework module must import the Gecko runtime Swift support contract",
    )
    require('"Utils.h"' in gecko_header, "framework module must expose the shared native runtime contract")
    require_header_closure(BRIDGE)
    require_header_closure(GECKO_HEADER)

    entry = (ROOT / "App" / "main.swift").read_text(encoding="utf-8")
    # Production path: start the coordinator before engine main, and never defer-stop
    # around that entry (teardown races with launch).
    production = entry
    if "#else" in entry:
        production = entry.rsplit("#else", 1)[-1]
    require(
        "RuntimeJITCoordinator.shared.stop()" not in production,
        "main.swift must not stop JIT around engine main entry",
    )
    require("configureUnsandboxedAppDataDirectories()" in entry, "main.swift must keep iOS-13 no-sandbox profile helper")
    require("MOZ_APP_DATA" in entry, "main.swift must set MOZ_APP_DATA only on the iOS-13 path")
    require("#unavailable(iOS 14.0)" in entry or "#unavailable(iOS 14" in entry, "MOZ_APP_DATA must be gated to iOS 13 like Reynard")
    require("updateJetsamControl(getpid())" in entry, "main process jetsam must be raised before Gecko")
    # Phase 4: the no-sandbox short-circuit was removed from RuntimeJITCoordinator.
    # JITEnabler.enableJIT now internally dispatches ptrace (TrollStore) vs
    # RPPairing (iOS 17.4+ non-TrollStore), so the coordinator must NOT pre-filter.
    require("usesUnsandboxedPtrace" not in source, "coordinator must not gate ptrace on no-sandbox (Phase 4 removed short-circuit)")
    require(
        'finish(pid: pid, enabled: false, reason: "no-unsandboxed-entitlement")' not in source,
        "no-sandbox skip path must be removed (non-TrollStore installs use RPPairing)",
    )

    print("PASS: exactly-once child JIT orchestration contract")


if __name__ == "__main__":
    main()
