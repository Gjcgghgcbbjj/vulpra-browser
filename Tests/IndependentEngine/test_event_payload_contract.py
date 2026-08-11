#!/usr/bin/env python3
"""engine->App event payload key contract (annex 73/74).

Cross-checks the keys the v5 engine sends for user-visible events against the
keys the App reads in VulpraEngineSession.swift. Catches C2-class key name
mismatches (contentType/mimeType C3, uri/elementSrc vs linkUri/srcUri C4).

Engine senders:
- GeckoView:ExternalResponse*  -> C++ widget/uikit/ExternalResponseService.mm
                                  (compiled only; contract snapshot in CI)
- GeckoView:ContextMenu        -> packaged actors/ContentDelegateChild.sys.mjs
- GeckoView:OnNewSession       -> packaged modules/GeckoViewNavigation.sys.mjs
- GeckoView:OnLoadError        -> packaged actors/LoadURIDelegateChild.sys.mjs

The actors are verified against the packaged runtime (exploded resources dir
or omni.ja); the compiled-only C++ payload keys are verified against the local
source tree when present, otherwise against the checked-in contract snapshot
(accepted only when its provenance matches engine-artifact-lock.json).
"""
import pathlib
import re
from pathlib import Path

from engine_sources import (ROOT, read_packaged, read_source,
                            require_snapshot_matches_lock, snapshot,
                            snapshot_matches_lock)

SESSION = ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift"
SERVICE = read_source("widget/uikit/ExternalResponseService.mm")

# Engine-sent keys that MUST be covered by an App reader (per event).
REQUIRED = {
    "GeckoView:ContextMenu": {"uri", "elementSrc"},
    "GeckoView:OnNewSession": {"uri", "newSessionId"},
    "GeckoView:OnLoadError": {"uri", "error"},
    "GeckoView:ExternalResponse": {"url", "localFilePath", "filename", "mimeType", "contentLength"},
    "GeckoView:ExternalResponseProgress": {"localFilePath", "bytesReceived"},
    "GeckoView:ExternalResponseComplete": {"localFilePath", "succeeded"},
}


def verify_external_response_source(problems: list) -> None:
    """Payload keys from ExternalResponseService.mm: live source when present,
    otherwise the checked-in contract snapshot (compiled-only evidence)."""
    keys = ("url", "mimeType", "localFilePath", "bytesReceived", "succeeded",
            "filename", "contentLength")
    if SERVICE is not None:
        for key in keys:
            if f'"{key}"' not in SERVICE:
                problems.append(f"ExternalResponseService.mm missing payload key {key}")
        return
    snap_keys = (snapshot().get("externalResponsePayloadKeys") or [])
    if not snap_keys:
        problems.append("ExternalResponseService.mm unavailable and no "
                        "externalResponsePayloadKeys snapshot present")
        return
    require_snapshot_matches_lock(problems, "event payload")
    if not snapshot_matches_lock():
        return
    missing = [k for k in keys if k not in snap_keys]
    if missing:
        problems.append(f"externalResponsePayloadKeys snapshot missing {missing}")


def verify_packaged_actors(problems: list) -> None:
    """The GeckoView actors ship inside omni.ja, so they must be verified from
    the packaged runtime (exploded resources dir or omni.ja archive)."""
    child = read_packaged("actors/ContentDelegateChild.sys.mjs")
    if child is None:
        problems.append("packaged actors/ContentDelegateChild.sys.mjs not found")
    else:
        for pat in (r"\n            uri,", r"\n            elementSrc:", r"\n            title:"):
            if not re.search(pat, child):
                problems.append(f"ContentDelegateChild.sys.mjs missing msg key {pat}")
    nav = read_packaged("modules/GeckoViewNavigation.sys.mjs")
    if nav is None:
        problems.append("packaged modules/GeckoViewNavigation.sys.mjs not found")
    else:
        for key in ("uri:", "newSessionId,"):
            if key not in nav:
                problems.append(f"GeckoViewNavigation.sys.mjs missing message key {key}")
    load = read_packaged("actors/LoadURIDelegateChild.sys.mjs")
    if load is None:
        problems.append("packaged actors/LoadURIDelegateChild.sys.mjs not found")
    else:
        for key in ("uri:", "error:", "errorModule:", "errorClass,"):
            if key not in load:
                problems.append(f"LoadURIDelegateChild.sys.mjs missing msg key {key}")


def main() -> int:
    problems = []
    verify_external_response_source(problems)
    verify_packaged_actors(problems)
    if problems:
        for p in problems:
            print("FAIL(engine source):", p)
        raise SystemExit("FAIL: engine source contract broken")

    if not SESSION.is_file():
        raise SystemExit(f"FAIL: missing {SESSION}")
    src = SESSION.read_text(encoding="utf-8")
    app_keys = set(re.findall(r'payload\["([^"]+)"\]', src))

    violations = []
    for ev, required in REQUIRED.items():
        missing = sorted(required - app_keys)
        if missing:
            violations.append((ev, missing))
    if violations:
        for ev, missing in violations:
            print(f"FAIL: {ev} engine sends {sorted(REQUIRED[ev])} but App never "
                  f"reads {missing} (C3/C4-class key mismatch)")
        raise SystemExit(f"FAIL: {len(violations)} event payload contract violation(s)")
    total = sum(len(v) for v in REQUIRED.values())
    print(f"PASS: {total} required engine->App payload keys are covered by App readers")
    return 0


if __name__ == "__main__":
    if len(__import__("sys").argv) > 1:
        SESSION = pathlib.Path(__import__("sys").argv[1])
    raise SystemExit(main())
