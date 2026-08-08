#!/usr/bin/env python3
"""Draft (NOT committed): engine->App event payload key contract (annex 73/74).

Cross-checks the keys the v5 engine sends for user-visible events against the
keys the App reads in VulpraEngineSession.swift. Catches C2-class key name
mismatches (contentType/mimeType C3, uri/elementSrc vs linkUri/srcUri C4).

Engine senders:
- GeckoView:ExternalResponse*  -> C++ widget/uikit/ExternalResponseService.mm
- GeckoView:ContextMenu        -> omni.ja actors/ContentDelegateChild.sys.mjs
- GeckoView:OnNewSession       -> omni.ja modules/GeckoViewNavigation.sys.mjs
- GeckoView:OnLoadError        -> omni.ja actors/LoadURIDelegateChild.sys.mjs

HEAD FAILs (mimeType + uri/elementSrc not read); C3+C4 patched PASSes.
"""
import pathlib
import re
from pathlib import Path

def find_root() -> Path:
    p = Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "Engine" / "VulpraEngineKit").is_dir():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from " + str(Path(__file__).resolve().parent))

ROOT = find_root()
SESSION = ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift"
GECKO = ROOT / ".build/gecko-source-full-patched-20260730"
SERVICE = GECKO / "widget/uikit/ExternalResponseService.mm"
OMNI = ROOT / ".build/r0.3-device-full/runtime/resources/omni.ja"

# Engine-sent keys that MUST be covered by an App reader (per event).
REQUIRED = {
    "GeckoView:ContextMenu": {"uri", "elementSrc"},
    "GeckoView:OnNewSession": {"uri", "newSessionId"},
    "GeckoView:OnLoadError": {"uri", "error"},
    "GeckoView:ExternalResponse": {"url", "localFilePath", "filename", "mimeType", "contentLength"},
    "GeckoView:ExternalResponseProgress": {"localFilePath", "bytesReceived"},
    "GeckoView:ExternalResponseComplete": {"localFilePath", "succeeded"},
}

def verify_engine_sources() -> list:
    """Sanity-check that the engine really sends these keys (source-verified)."""
    problems = []
    if not SERVICE.is_file():
        problems.append(f"missing engine source {SERVICE}")
        return problems
    src = SERVICE.read_text(encoding="utf-8")
    for key in ("url", "mimeType", "localFilePath", "bytesReceived", "succeeded", "filename", "contentLength"):
        if f'"{key}"' not in src:
            problems.append(f"ExternalResponseService.mm missing payload key {key}")
    import zipfile
    if not OMNI.is_file():
        problems.append(f"missing omni.ja {OMNI}")
        return problems
    with zipfile.ZipFile(OMNI) as z:
        child = z.read("actors/ContentDelegateChild.sys.mjs").decode("utf-8", "replace")
        for pat in (r"\n            uri,", r"\n            elementSrc:", r"\n            title:"):
            if not re.search(pat, child):
                problems.append(f"ContentDelegateChild.sys.mjs missing msg key {pat}")
        nav = z.read("modules/GeckoViewNavigation.sys.mjs").decode("utf-8", "replace")
        for key in ("uri:", "newSessionId,"):
            if key not in nav:
                problems.append(f"GeckoViewNavigation.sys.mjs missing message key {key}")
        load = z.read("actors/LoadURIDelegateChild.sys.mjs").decode("utf-8", "replace")
        for key in ("uri:", "error:", "errorModule:", "errorClass,"):
            if key not in load:
                problems.append(f"LoadURIDelegateChild.sys.mjs missing msg key {key}")
    return problems

def main() -> int:
    problems = verify_engine_sources()
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
