#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
OWNERSHIP = ROOT / "Configuration/engine-ownership.json"
GATES = ROOT / "Configuration/engine-cutover-gates.json"
LOCK = ROOT / "Configuration/engine-artifact-lock.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-cutover", action="store_true")
    parser.add_argument("--require-r0-complete", action="store_true")
    args = parser.parse_args()
    ownership = json.loads(OWNERSHIP.read_text(encoding="utf-8"))
    readiness = json.loads(GATES.read_text(encoding="utf-8"))
    lock = json.loads(LOCK.read_text(encoding="utf-8"))
    require(readiness.get("schemaVersion") == 1, "cutover gate schemaVersion must be 1")
    require(readiness.get("targetState") == "independent", "cutover target state must be independent")
    if args.require_cutover or args.require_r0_complete:
        require(lock.get("artifactFormatVersion") == 5,
                "cutover requires a promoted Gecko v5 artifact pair")
        evidence = readiness.get("r0Evidence")
        require(isinstance(evidence, dict) and
                isinstance(evidence.get("repeatProducerRunIds"), list) and
                len(evidence["repeatProducerRunIds"]) == 2 and
                all(type(value) is int and value > 0 for value in evidence["repeatProducerRunIds"]) and
                len(set(evidence["repeatProducerRunIds"])) == 2 and
                isinstance(evidence.get("repeatCompileRunIds"), list) and
                len(evidence["repeatCompileRunIds"]) == 2 and
                all(type(value) is int and value > 0 for value in evidence["repeatCompileRunIds"]) and
                len(set(evidence["repeatCompileRunIds"])) == 2 and
                type(evidence.get("selectedProducerRunId")) is int and
                evidence["selectedProducerRunId"] in evidence["repeatProducerRunIds"] and
                evidence["selectedProducerRunId"] == lock.get("producerRunId"),
                "cutover repeat producer or compile evidence run IDs are incomplete")
        device = lock.get("device")
        simulator = lock.get("simulator")
        require(isinstance(device, dict) and isinstance(simulator, dict) and
                device.get("compiledByRunId") == simulator.get("compiledByRunId") and
                device.get("compiledByRunId") in evidence["repeatCompileRunIds"],
                "promoted pair is not bound to an independent repeat compile run")
    if args.require_r0_complete:
        evidence = readiness["r0Evidence"]
        require(type(evidence.get("simulatorGateRunId")) is int and
                evidence["simulatorGateRunId"] > 0 and
                type(evidence.get("packageRunId")) is int and evidence["packageRunId"] > 0,
                "R0 Simulator or package evidence run ID is incomplete")
        retired_paths = (
            "Tools/Engine/produce-simulator-artifact.sh",
            ".github/workflows/produce-simulator-artifact.yml",
            "Tests/IndependentEngine/test_simulator_producer.py",
            "Tests/IndependentEngine/test_artifact_contract.py",
            "Configuration/engine-artifact-v4.json",
            "Configuration/engine-artifact-simulator-v4.json",
        )
        for relative in retired_paths:
            require(not (ROOT / relative).exists(), f"retired v4 path remains: {relative}")
        retired_pattern = re.compile(
            r"apple-vtool-set-build-version-iossim-15|produce-simulator-artifact|"
            r"engine-artifact-(?:simulator-)?v4|vulpra-engine-v4-candidate|"
            r"jit-ready-fd|ReportJITStatusForChild|EngineProcessBootstrap|"
            r"reassertActivationIfNeeded"
        )
        active_roots = (
            ROOT / "App", ROOT / "Engine/VulpraEngineKit",
            ROOT / "Engine/VulpraEngineProcess", ROOT / "Engine/GeckoPatches",
            ROOT / "Tools/Release", ROOT / ".github",
        )
        active_files = [ROOT / "README.md"]
        for active_root in active_roots:
            active_files.extend(path for path in active_root.rglob("*") if path.is_file())
        for path in active_files:
            text = path.read_text(encoding="utf-8", errors="replace")
            match = retired_pattern.search(text)
            require(match is None,
                    f"retired active-path token remains: {path.relative_to(ROOT)}:{match.group(0) if match else ''}")

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
        if args.require_cutover or args.require_r0_complete:
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
