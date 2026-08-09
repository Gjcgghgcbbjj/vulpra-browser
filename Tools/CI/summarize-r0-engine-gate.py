#!/usr/bin/env python3
"""Validate and summarize repeated R0 Simulator navigation evidence."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys


ATTEMPT_KEYS = {
    "attempt", "locationMatched", "pageCompleted", "renderedDarkPixels",
    "loadToCompleteMs", "appSurvived", "crashCount", "lifecycleEvents",
    "requestedLaunchIDs", "connectedLaunchIDs", "failedLaunchIDs", "openLaunchIDs",
    "deliveryMethod", "warmSettleSeconds", "gateDispatchStatus", "openurlStatus",
    "launchStatus", "launchAttempts", "logShowStatus", "logEvidenceSource",
    "tabSwitchStatus", "engineEventStats", "browserTabDeactivatedCount",
    "initialLoadPath", "initialLoadDeferredMs",
}
EVENT_KEYS = {
    "launchID", "childID", "processType", "pid", "stage",
    "monotonicTimestampNanoseconds", "failureCode", "reason",
}
STAGE_ORDER = {
    "requested": 1,
    "extensionConnected": 2,
    "bootstrapAcknowledged": 3,
    "ipcConnected": 4,
    "failed": 5,
    "terminated": 6,
}
FAILURE_CODES = {
    "none", "extensionStart", "xpcTransport", "bootstrapReply", "processLaunch",
    "ipcBeforeConnection", "terminatedBeforeOutcome", "invalidTransition",
}


class GateError(ValueError):
    pass


def fail(message: str) -> None:
    raise GateError(message)


def integer(value: object, label: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        fail(f"{label} must be an integer >= {minimum}")
    return value


def boolean(value: object, label: str) -> bool:
    if type(value) is not bool:
        fail(f"{label} must be a Boolean")
    return value


def validate_event(event: object, index: int) -> dict[str, object]:
    if not isinstance(event, dict) or set(event) != EVENT_KEYS:
        fail(f"lifecycle event {index} has invalid keys")
    integer(event["launchID"], f"lifecycle event {index} launchID", 1)
    integer(event["childID"], f"lifecycle event {index} childID", 1)
    process_type = event["processType"]
    if not isinstance(process_type, str) or not process_type or len(process_type.encode()) > 64:
        fail(f"lifecycle event {index} processType is invalid")
    pid = event["pid"]
    if pid is not None:
        integer(pid, f"lifecycle event {index} pid", 1)
    stage = event["stage"]
    if stage not in STAGE_ORDER:
        fail(f"lifecycle event {index} stage is invalid")
    integer(
        event["monotonicTimestampNanoseconds"],
        f"lifecycle event {index} monotonic timestamp", 1,
    )
    failure_code = event["failureCode"]
    if failure_code not in FAILURE_CODES:
        fail(f"lifecycle event {index} failureCode is invalid")
    reason = event["reason"]
    if reason is not None and (not isinstance(reason, str) or not reason or len(reason.encode()) > 160):
        fail(f"lifecycle event {index} reason is invalid")
    if stage == "failed":
        if failure_code == "none" or reason is None:
            fail(f"lifecycle event {index} failed without typed reason")
    elif failure_code != "none" or reason is not None:
        fail(f"lifecycle event {index} non-failure carries failure data")
    if stage in {"bootstrapAcknowledged", "ipcConnected"} and pid is None:
        fail(f"lifecycle event {index} {stage} has no process identifier")
    return event


def validate_lifecycle(events_value: object) -> tuple[list[int], list[int], list[int], list[int]]:
    if not isinstance(events_value, list) or not events_value:
        fail("attempt lifecycleEvents must be a non-empty list")
    records: dict[int, dict[str, object]] = {}
    requested_order: list[int] = []
    for index, raw_event in enumerate(events_value):
        event = validate_event(raw_event, index)
        launch_id = event["launchID"]
        record = records.get(launch_id)
        if record is None:
            if event["stage"] != "requested":
                fail(f"launch {launch_id} first event is not requested")
            records[launch_id] = {
                "childID": event["childID"],
                "processType": event["processType"],
                "timestamp": event["monotonicTimestampNanoseconds"],
                "stage": "requested",
                "seen": {"requested"},
                "outcome": None,
                "terminated": False,
            }
            requested_order.append(launch_id)
            continue
        if record["childID"] != event["childID"] or record["processType"] != event["processType"]:
            fail(f"launch {launch_id} identity changed")
        if event["monotonicTimestampNanoseconds"] <= record["timestamp"]:
            fail(f"launch {launch_id} timestamp is zero or regressive")
        if record["terminated"]:
            fail(f"launch {launch_id} has an event after termination")
        stage = event["stage"]
        if stage in record["seen"]:
            fail(f"launch {launch_id} has duplicate stage {stage}")
        previous = record["stage"]
        expected = {
            "requested": "extensionConnected",
            "extensionConnected": "bootstrapAcknowledged",
            "bootstrapAcknowledged": "ipcConnected",
            "ipcConnected": "terminated",
            "failed": "terminated",
        }.get(previous)
        if stage == "failed":
            if record["outcome"] is not None or STAGE_ORDER[previous] >= STAGE_ORDER["ipcConnected"]:
                fail(f"launch {launch_id} failed after an outcome")
            record["outcome"] = "failed"
        elif stage != expected:
            fail(f"launch {launch_id} stage is skipped or regressive: {previous} -> {stage}")
        elif stage == "ipcConnected":
            record["outcome"] = "connected"
        elif stage == "terminated":
            if record["outcome"] is None:
                fail(f"launch {launch_id} terminated before an outcome")
            record["terminated"] = True
        record["timestamp"] = event["monotonicTimestampNanoseconds"]
        record["stage"] = stage
        record["seen"].add(stage)

    requested = sorted(requested_order)
    connected = sorted(key for key, value in records.items() if value["outcome"] == "connected")
    failed = sorted(key for key, value in records.items() if value["outcome"] == "failed")
    open_ids = sorted(key for key, value in records.items() if value["outcome"] is None)
    if set(connected) & set(failed):
        fail("a child launch appears in both outcome sets")
    return requested, connected, failed, open_ids


def id_array(value: object, label: str) -> list[int]:
    if not isinstance(value, list):
        fail(f"{label} must be an array")
    result = [integer(item, label, 1) for item in value]
    if result != sorted(set(result)):
        fail(f"{label} must contain sorted unique launch IDs")
    return result


def validate_attempt(value: object) -> dict[str, object]:
    if not isinstance(value, dict) or set(value) != ATTEMPT_KEYS:
        fail("attempt has invalid keys")
    attempt = integer(value["attempt"], "attempt", 1)
    for key in ("locationMatched", "pageCompleted", "appSurvived"):
        if not boolean(value[key], f"attempt {attempt} {key}"):
            fail(f"attempt {attempt} {key} is false")
    if integer(value["renderedDarkPixels"], f"attempt {attempt} renderedDarkPixels") < 1000:
        fail(f"attempt {attempt} screenshot is visually blank")
    integer(value["loadToCompleteMs"], f"attempt {attempt} loadToCompleteMs")
    if integer(value["crashCount"], f"attempt {attempt} crashCount") != 0:
        fail(f"attempt {attempt} contains a crash")
    delivery = value["deliveryMethod"]
    if not isinstance(delivery, str) or delivery not in {"gate-http-dispatch", "simctl-openurl"}:
        fail(f"attempt {attempt} deliveryMethod is invalid")
    if delivery != "gate-http-dispatch":
        fail(f"attempt {attempt} deliveryMethod must be gate-http-dispatch")
    if not isinstance(value["openurlStatus"], str) or not value["openurlStatus"]:
        fail(f"attempt {attempt} openurlStatus is invalid")
    integer(value["warmSettleSeconds"], f"attempt {attempt} warmSettleSeconds")
    gate_status = integer(value["gateDispatchStatus"], f"attempt {attempt} gateDispatchStatus", -1)
    if gate_status != 0:
        fail(f"attempt {attempt} gate dispatch did not succeed: status {gate_status}")
    integer(value["launchStatus"], f"attempt {attempt} launchStatus")
    integer(value["launchAttempts"], f"attempt {attempt} launchAttempts", 1)
    integer(value["logShowStatus"], f"attempt {attempt} logShowStatus")
    evidence_source = value["logEvidenceSource"]
    if not isinstance(evidence_source, str) or not evidence_source:
        fail(f"attempt {attempt} logEvidenceSource is invalid")
    tab_switch_status = value["tabSwitchStatus"]
    if tab_switch_status != "completed":
        fail(f"attempt {attempt} tab-switch-during-load scenario did not complete: {tab_switch_status}")
    stats = value["engineEventStats"]
    if not isinstance(stats, dict) or set(stats) != {"delivered", "coalesced", "total"}:
        fail(f"attempt {attempt} engineEventStats has invalid keys")
    delivered = integer(stats["delivered"], f"attempt {attempt} engineEventStats.delivered", 1)
    coalesced = integer(stats["coalesced"], f"attempt {attempt} engineEventStats.coalesced")
    total = integer(stats["total"], f"attempt {attempt} engineEventStats.total", 1)
    if total != delivered + coalesced:
        fail(f"attempt {attempt} engineEventStats total does not equal delivered + coalesced")
    integer(
        value["browserTabDeactivatedCount"],
        f"attempt {attempt} browserTabDeactivatedCount", 1,
    )
    initial_path = value["initialLoadPath"]
    if not isinstance(initial_path, bool):
        fail(f"attempt {attempt} initialLoadPath must be a Boolean")
    deferred_ms = integer(
        value["initialLoadDeferredMs"], f"attempt {attempt} initialLoadDeferredMs", -1,
    )
    if initial_path and deferred_ms < 0:
        fail(f"attempt {attempt} deferred load path is missing its deferral measurement")
    derived = validate_lifecycle(value["lifecycleEvents"])
    labels = ("requestedLaunchIDs", "connectedLaunchIDs", "failedLaunchIDs", "openLaunchIDs")
    stored_connected = id_array(value["connectedLaunchIDs"], f"attempt {attempt} connectedLaunchIDs")
    stored_failed = id_array(value["failedLaunchIDs"], f"attempt {attempt} failedLaunchIDs")
    if set(stored_connected) & set(stored_failed):
        fail(f"attempt {attempt} stores a launch in both outcome sets")
    for label, expected in zip(labels, derived):
        if id_array(value[label], f"attempt {attempt} {label}") != expected:
            fail(f"attempt {attempt} stored/derived {label} mismatch")
    if derived[3]:
        fail(f"attempt {attempt} has open child launches: {derived[3]}")
    if derived[2]:
        fail(f"attempt {attempt} has failed child launches: {derived[2]}")
    return value


def load_attempts(input_directory: Path) -> list[dict[str, object]]:
    if not input_directory.is_dir():
        fail(f"input directory does not exist: {input_directory}")
    attempts = []
    for path in sorted(input_directory.glob("*.json")):
        try:
            attempts.append(validate_attempt(json.loads(path.read_text(encoding="utf-8"))))
        except (OSError, json.JSONDecodeError) as error:
            fail(f"invalid attempt file {path.name}: {error}")
    return attempts


def summarize(attempts: list[dict[str, object]], expected_count: int) -> dict[str, object]:
    identifiers = [attempt["attempt"] for attempt in attempts]
    if identifiers != list(range(1, expected_count + 1)):
        fail(f"attempt identifiers must be exactly 1...{expected_count}, got {identifiers}")
    durations = sorted(attempt["loadToCompleteMs"] for attempt in attempts)
    p95 = durations[math.ceil(len(durations) * 0.95) - 1]
    maximum = durations[-1]
    if p95 > 15000:
        fail(f"p95 load-to-complete exceeds 15000 ms: {p95}")
    if maximum > 30000:
        fail(f"maximum load-to-complete exceeds 30000 ms: {maximum}")
    return {
        "schemaVersion": 1,
        "r0Attempts": expected_count,
        "r0Passed": len(attempts),
        "p95LoadToCompleteMs": p95,
        "maxLoadToCompleteMs": maximum,
        "totalRequestedLaunches": sum(len(attempt["requestedLaunchIDs"]) for attempt in attempts),
        "totalConnectedLaunches": sum(len(attempt["connectedLaunchIDs"]) for attempt in attempts),
        "totalFailedLaunches": 0,
        "totalOpenLaunches": 0,
        "scenarioCompletedAttempts": sum(
            1 for attempt in attempts if attempt["tabSwitchStatus"] == "completed"
        ),
        "totalDeliveredEvents": sum(attempt["engineEventStats"]["delivered"] for attempt in attempts),
        "totalCoalescedEvents": sum(attempt["engineEventStats"]["coalesced"] for attempt in attempts),
        "totalBrowserTabDeactivations": sum(attempt["browserTabDeactivatedCount"] for attempt in attempts),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--attempts", required=True, type=int)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.attempts <= 0:
            fail("attempt count must be positive")
        summary = summarize(load_attempts(args.input), args.attempts)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    except (OSError, GateError) as error:
        print(f"r0-engine-gate-error: {error}", file=sys.stderr)
        return 1
    print(
        f"PASS: R0 engine gate {summary['r0Passed']}/{summary['r0Attempts']} "
        f"p95={summary['p95LoadToCompleteMs']}ms max={summary['maxLoadToCompleteMs']}ms"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
