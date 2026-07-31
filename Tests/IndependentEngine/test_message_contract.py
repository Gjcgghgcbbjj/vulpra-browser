#!/usr/bin/env python3
import json
from pathlib import Path
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "Configuration/engine-message-contract.json"
RESOURCES = ROOT / ".build/engine/runtime/resources"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def load_runtime_evidence() -> str:
    sources = [
        path.read_text(encoding="utf-8", errors="ignore")
        for path in RESOURCES.rglob("*")
        if path.is_file() and path.suffix in {".js", ".mjs"}
    ]
    omnijar = RESOURCES / "omni.ja"
    if omnijar.is_file():
        with ZipFile(omnijar) as archive:
            sources.extend(
                archive.read(name).decode("utf-8", errors="ignore")
                for name in archive.namelist()
                if name.endswith((".js", ".mjs"))
            )
    return "\n".join(sources)


def main() -> None:
    value = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value.get("schemaVersion") == 1, "message contract schema must be 1")
    commands = value.get("commands")
    events = value.get("events")
    require(isinstance(commands, dict) and commands, "commands must be non-empty")
    require(isinstance(events, dict) and events, "events must be non-empty")

    names = []
    for category in (commands, events):
        for key, entry in category.items():
            require(isinstance(entry, dict), f"invalid contract entry: {key}")
            name = entry.get("name")
            fields = entry.get("required")
            require(isinstance(name, str) and name.startswith("GeckoView:"), f"invalid event name: {key}")
            require(isinstance(fields, list) and len(fields) == len(set(fields)), f"invalid required fields: {key}")
            names.append(name)
    require(len(names) == len(set(names)), "message names must be unique")

    evidence = load_runtime_evidence()
    compiled_only = {
        "GeckoView:ExternalResponse",
        "GeckoView:ExternalResponseProgress",
        "GeckoView:ExternalResponseComplete",
    }
    for name in names:
        require(name in evidence or name in compiled_only, f"message lacks runtime evidence: {name}")

    bridge = (ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift").read_text(encoding="utf-8")
    for name in names:
        require(name in bridge or name in {
            "GeckoView:ClearData", "GeckoView:SetLocale"
        }, f"session bridge does not own message: {name}")
    for token in ("private var pendingCommands", "pendingCommands.append",
                  "flushPendingCommands()", "pendingCommands.removeAll()"):
        require(token in bridge, f"session command serialization is missing {token}")
    require("navigationObserver?.engineSessionDidOpen(id)" in bridge,
            "session does not publish native view readiness")
    require(bridge.index("navigationObserver?.engineSessionDidOpen(id)") <
            bridge.index("flushPendingCommands()", bridge.index("navigationObserver?.engineSessionDidOpen(id)")),
            "session flushes navigation before the native view can be attached")
    require('guard let window else {\n            Self.logger.error("Engine command rejected before window open' not in bridge,
            "session still drops commands while its window is opening")
    require("NS_ShutdownXPCOM" not in bridge, "unexported shutdown ABI leaked into session")
    require("ReportJITStatusForChild" not in bridge, "status report must not become an interpreter selector")
    print("PASS: artifact-derived engine message contract")


if __name__ == "__main__":
    main()
