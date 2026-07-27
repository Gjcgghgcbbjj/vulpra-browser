#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
OWNERSHIP = ROOT / "Configuration/engine-ownership.json"
GATES = ROOT / "Configuration/engine-cutover-gates.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-cutover", action="store_true")
    args = parser.parse_args()
    ownership = json.loads(OWNERSHIP.read_text(encoding="utf-8"))
    readiness = json.loads(GATES.read_text(encoding="utf-8"))
    require(readiness.get("schemaVersion") == 1, "cutover gate schemaVersion must be 1")
    require(readiness.get("targetState") == "independent", "cutover target state must be independent")

    required = [item for transition in ownership["transitions"] for item in transition["requirements"]]
    gates = readiness.get("gates")
    require(isinstance(gates, list), "cutover gates must be a list")
    ids = [gate.get("id") for gate in gates if isinstance(gate, dict)]
    require(ids == required, "cutover gates must match ownership transition requirements in order")
    require(len(ids) == len(set(ids)), "cutover gates contain duplicate IDs")
    for gate in gates:
        require(gate.get("status") in {"open", "verified"}, f"invalid gate status: {gate}")
        evidence = gate.get("evidence")
        require(isinstance(evidence, list), f"gate evidence must be a list: {gate}")
        if gate["status"] == "verified":
            require(evidence, f"verified gate has no evidence: {gate['id']}")

    project = (ROOT / "Vulpra.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    require("VulpraEngineKit.framework in Embed Frameworks" in project, "independent framework is not embedded")
    require("Vulpra Engine Process.appex in Embed App Extensions" in project, "independent process is not embedded")
    app_sources = "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "App").rglob("*.swift"))
    require("import VulpraEngineKit" in app_sources, "App is not migrated to VulpraEngineKit")
    require("import GeckoView" not in app_sources, "old App adapter remains active")

    open_gates = [gate["id"] for gate in gates if gate["status"] != "verified"]
    if open_gates:
        message = "cutover-not-ready: " + ",".join(open_gates)
        if args.require_cutover:
            print(message, file=sys.stderr)
            return 2
        print(message)
        print("PASS: independent cutover remains correctly gated")
        return 0
    require(ownership.get("state") == "independent", "all gates verified but ownership state is not independent")
    print("cutover-ready")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
