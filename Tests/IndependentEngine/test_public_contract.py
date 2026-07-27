#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PUBLIC = ROOT / "Engine/VulpraEngineKit/Public"
EXPECTED = {
    "EngineCapabilities.swift": (
        "public enum EngineExecutionMode",
        "case interpreter",
        "public struct EngineCapabilities",
    ),
    "EngineRuntime.swift": (
        "public struct EngineRuntimeConfiguration",
        "public enum EngineRuntimeState",
        "public protocol EngineRuntime",
        "func start(",
        "func makeSession(",
    ),
    "EngineSession.swift": (
        "public struct EngineSessionConfiguration",
        "public protocol EngineSession",
        "func open(",
        "func close(",
        "func load(",
        "func goBack(",
        "func goForward(",
        "func reload(",
        "func stop(",
        "public enum EngineSessionState",
        "var state: EngineSessionState",
    ),
    "EngineEvents.swift": (
        "public struct EngineSessionID",
        "public struct EngineNavigationEvent",
        "public enum EngineProgressEvent",
        "public enum EngineTerminationReason",
        "public protocol EngineNavigationObserver",
        "func engineSessionDidOpen(_ id: EngineSessionID)",
        "public protocol EngineProgressObserver",
    ),
    "EngineView.swift": (
        "import UIKit",
        "@MainActor",
        "public protocol EngineView",
        "var contentView: UIView",
        "func setVisible(",
    ),
    "EngineFeatures.swift": (
        "public struct EngineContextMenuElement",
        "public struct EngineDownloadResponse",
        "public struct EnginePermissionRequest",
        "public struct EnginePromptRequest",
        "public struct EngineStorageClearOptions",
        "public protocol EnginePromptHandler",
        "public protocol EnginePermissionHandler",
        "public protocol EngineDownloadHandler",
    ),
}

FORBIDDEN = (
    "Gecko",
    "GeckoView",
    "WebKit",
    "WKWebView",
    "[String: Any]",
    "NSDictionary",
    "UnsafePointer",
    "UnsafeMutablePointer",
    "OpaquePointer",
    "NotificationCenter",
    "static let shared",
    "fatalError(",
    "func shutdown(",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> None:
    require(PUBLIC.is_dir(), "missing Engine/VulpraEngineKit/Public")
    actual = {path.name for path in PUBLIC.glob("*.swift")}
    require(actual == set(EXPECTED), f"unexpected public engine files: {sorted(actual)}")

    combined = ""
    for name, tokens in EXPECTED.items():
        path = PUBLIC / name
        text = path.read_text(encoding="utf-8")
        combined += f"\n{text}"
        for token in tokens:
            require(token in text, f"{name} is missing contract token: {token}")
        lines = len(text.splitlines())
        require(lines < 220, f"public engine owner exceeds 220-line budget: {name} ({lines})")
        if name != "EngineView.swift":
            require("import UIKit" not in text and "UIView" not in text, f"UIKit leaked into {name}")

    for token in FORBIDDEN:
        require(token not in combined, f"public engine contract contains forbidden token: {token}")

    require("Sendable" in combined, "public engine values must declare concurrency boundaries")
    require("EnginePendingRequest" not in combined and "EngineRequestDisposition" not in combined,
            "unused pending-request promises must stay retired")
    require("var id: EngineSessionID" in combined, "sessions need a Vulpra-owned identifier")
    require("isPrivate" in combined, "session configuration must preserve private mode")
    require("URL" in combined, "navigation contracts must use typed URLs")

    print("PASS: VulpraEngineKit public contract")


if __name__ == "__main__":
    main()
