#!/usr/bin/env python3
"""GeckoView:Preferences:SetPref channel contract.

The App injects prefs through the shared GeckoViewPreferences JS handler, which
matches types against Ci.nsIPrefBranch constants of the v5 engine. In this
Firefox version the PreferenceType cenum is PREF_INVALID=0 / PREF_STRING=32 /
PREF_INT=64 / PREF_BOOL=128 (NOT the legacy 0/1/2). This test cross-checks
every injected pref name and type constant against engine evidence:

- pref name must exist verbatim in the engine (StaticPrefList.yaml, packaged
  greprefs.js/mobile.js, or the checked-in contract snapshot);
- type must be 32/64/128 AND match the engine-declared pref type.

Evidence resolution (engine_sources.py): local full source tree when present
(strongest), else the packaged runtime resources (greprefs.js +
defaults/pref/mobile.js) plus the checked-in contract snapshot for
StaticPrefs (StaticPrefList.yaml is not packaged). The snapshot is accepted
only when its provenance matches Configuration/engine-artifact-lock.json.
"""
import pathlib
import re
import subprocess
import sys
from pathlib import Path

from engine_sources import (ROOT, local_source_tree, read_packaged,
                            read_source, require_snapshot_matches_lock,
                            snapshot, snapshot_matches_lock)

PREF_INVALID, PREF_STRING, PREF_INT, PREF_BOOL = 0, 32, 64, 128

# Strongest-available sources (None in CI where the source tree is absent).
STATIC_YAML = read_source("modules/libpref/init/StaticPrefList.yaml")
ALLJS = read_source("modules/libpref/init/all.js") or read_packaged("greprefs.js")
MOBILEJS = (read_source("mobile/ios/app/mobile.js")
            or read_packaged("defaults/pref/mobile.js"))
RUNTIME = ROOT / "Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift"


def static_type(pref: str):
    """Return engine type ('bool'|'int'|'string'|None) from StaticPrefList.yaml
    when available, else from the checked-in contract snapshot."""
    if STATIC_YAML is not None:
        s = STATIC_YAML
        m = re.search(r"- name: " + re.escape(pref) + r"\n(?:.*\n)*?\s+type: (\S+)", s)
        if not m:
            return None
        t = m.group(1).lower()
    else:
        t = (snapshot().get("prefTypes") or {}).get(pref)
        if t is None:
            return None
    if "bool" in t:
        return "bool"
    if "int" in t or t in ("uint32", "uint64", "int32", "int64"):
        return "int"
    if "string" in t:
        return "string"
    return None


def js_default_type(pref: str):
    """Return type from packaged/source pref() default value files."""
    for s in (ALLJS, MOBILEJS):
        if not s:
            continue
        m = re.search(r'pref\("' + re.escape(pref) + r'",\s*([^)]+?)\s*\)', s)
        if m:
            v = m.group(1).strip()
            if v in ("true", "false"):
                return "bool"
            if v.isdigit() or (v.startswith("-") and v[1:].isdigit()):
                return "int"
            if v.startswith('"'):
                return "string"
    return None


def cpp_reader_type(pref: str):
    """Return type from C++ readers (Preferences::GetBool/GetInt/GetString).
    Only available when the full source tree is checked out."""
    tree = local_source_tree()
    if tree is None:
        return None
    out = set()
    for line in run_grep(pref):
        if re.search(r'Get(Bool|Int|String)(Pref)?\("' + re.escape(pref) + r'"', line):
            for k in ("Bool", "Int", "String"):
                if f"Get{k}" in line:
                    out.add(k.lower())
    if len(out) == 1:
        return next(iter(out))
    return None


def run_grep(needle: str):
    tree = local_source_tree()
    if tree is None:
        return []
    r = subprocess.run(
        ["rg", "-l", "-F", needle, str(tree), "-g", "*.{cpp,h,mm,js,mjs,yaml}"],
        capture_output=True, text=True, timeout=120,
    )
    if r.returncode != 0:
        return []
    lines = []
    for f in r.stdout.splitlines():
        if not f:
            continue
        rr = subprocess.run(["rg", "-n", "-F", needle, f], capture_output=True, text=True)
        lines.extend(rr.stdout.splitlines())
    return lines


def packaged_preferences_handler() -> str:
    """Return GeckoViewPreferences.sys.mjs from the packaged runtime (actual
    artifact: exploded resources dir or omni.ja)."""
    for rel in ("modules/GeckoViewPreferences.sys.mjs",
                "modules/geckoview/GeckoViewPreferences.sys.mjs"):
        text = read_packaged(rel)
        if text:
            return text
    return ""


def verify_packaged_handler(problems: list) -> None:
    handler = packaged_preferences_handler()
    if not handler:
        problems.append("packaged GeckoViewPreferences.sys.mjs not found")
        return
    # Handler must destructure the v5 constants (32/64/128) from Ci.nsIPrefBranch
    # and must NOT hard-code legacy 0/1/2.
    if "const { PREF_STRING, PREF_BOOL, PREF_INT } = Ci.nsIPrefBranch;" not in handler:
        problems.append("packaged handler does not destructure PREF_* from Ci.nsIPrefBranch")
    for token in ("case PREF_STRING:", "case PREF_BOOL:", "case PREF_INT:"):
        if token not in handler:
            problems.append(f"packaged handler missing {token}")
    if "aData.prefs" not in handler or "pref.pref" not in handler or "pref.type" not in handler:
        problems.append("packaged handler does not read aData.prefs[] {pref,type,...}")
    if "setBranch == \"user\"" not in handler and "setBranch == \"default\"" not in handler:
        problems.append("packaged handler missing branch handling")
    if "warn`Attempted to set against an unknown type" not in handler:
        problems.append("packaged handler missing unknown-type warn (silent-fail path)")


def expected_constant(t: str) -> int:
    return {"bool": PREF_BOOL, "int": PREF_INT, "string": PREF_STRING}[t]


def verify_snapshot_consistency(problems: list, injections: list) -> None:
    """When the local source tree exists, the checked-in snapshot must agree
    with the live engine for every injected pref (drift guard)."""
    if STATIC_YAML is None and not snapshot():
        problems.append("StaticPrefList.yaml unavailable and no pref snapshot present")
        return
    if STATIC_YAML is not None and snapshot():
        require_snapshot_matches_lock(problems, "pref channel")
        if not snapshot_matches_lock():
            return
        snap_types = snapshot().get("prefTypes") or {}
        for pref, _ in injections:
            live = static_type(pref) or js_default_type(pref) or cpp_reader_type(pref)
            if live is None:
                continue
            snap = snap_types.get(pref)
            if snap != live:
                problems.append(
                    f"{pref}: snapshot type {snap} != live engine type {live}")


def main() -> int:
    if not RUNTIME.is_file():
        raise SystemExit(f"FAIL: missing {RUNTIME}")
    if STATIC_YAML is None and not (snapshot().get("prefTypes")):
        raise SystemExit("FAIL: StaticPrefList.yaml unavailable and no pref "
                         "contract snapshot found")
    if not ALLJS:
        raise SystemExit("FAIL: no all.js/greprefs.js pref defaults evidence")
    src = RUNTIME.read_text(encoding="utf-8")

    # Collect every injected pref + type inside SetPref messages.
    injections = re.findall(r'"pref": "([^"]+)",\s*"type": (\d+)', src)
    if not injections:
        raise SystemExit("FAIL: no GeckoView:Preferences:SetPref injections found")

    problems = []

    # Message shape must match GeckoViewPreferences.sys.mjs:
    #   onEvent SetPref -> aData.prefs[] -> {pref, type, value, branch}
    # (EventDispatcher.mm UnboxBundle/UnboxArray/UnboxValue convert the
    #  NSDictionary/NSArray payload into a JS object/array; numbers become
    #  JS doubles, so Swift Int/bool survive as numbers/booleans.)
    dispatch_count = src.count('type: "GeckoView:Preferences:SetPref"')
    prefs_key_count = src.count('"prefs":')
    if dispatch_count == 0:
        raise SystemExit("FAIL: no GeckoView:Preferences:SetPref dispatch found")
    if prefs_key_count != dispatch_count:
        problems.append(
            f"{dispatch_count} SetPref dispatches but {prefs_key_count} carry a "
            "\"prefs\" key (JS handler reads aData.prefs array)")

    shape = re.findall(
        r'"pref": "([^"]+)",\s*"type": \d+(.*?)\s*"branch":\s*"(\w+)"',
        src, re.S)
    for pref, middle, branch in shape:
        if '"value"' not in middle:
            problems.append(f"{pref}: pref dict missing \"value\" key "
                            "(JS handler calls setIntPref/setBoolPref(pref, value))")
        if branch != "user":
            problems.append(f"{pref}: branch must be \"user\" (Services.prefs), got \"{branch}\"")
        if not re.search(r'"value":(?!\s*")', middle):
            problems.append(f"{pref}: value must be a bool/int expression "
                            "(not a string literal; JS handler setIntPref/setBoolPref)")

    checked = 0
    for pref, typestr in injections:
        typ = int(typestr)
        checked += 1
        if typ not in (PREF_STRING, PREF_INT, PREF_BOOL):
            problems.append(f"{pref}: type {typ} is not a v5 PreferenceType constant (32/64/128)")
            continue

        # 1) pref name must exist verbatim in engine evidence
        found = (static_type(pref) is not None or js_default_type(pref) is not None
                 or run_grep(pref))
        if not found:
            problems.append(f"{pref}: pref name NOT found verbatim in engine evidence")

        # 2) type must match engine-declared type
        eng = static_type(pref) or js_default_type(pref) or cpp_reader_type(pref)
        if eng is None:
            problems.append(f"{pref}: cannot determine engine type from evidence")
        elif typ != expected_constant(eng):
            problems.append(
                f"{pref}: type {typ} != expected {expected_constant(eng)} (engine {eng})"
            )

    verify_packaged_handler(problems)
    verify_snapshot_consistency(problems, injections)

    if problems:
        for p in problems:
            print("FAIL:", p)
        raise SystemExit(f"FAIL: {len(problems)} pref channel contract violation(s) "
                         f"across {checked} injections")
    print(f"PASS: {checked} pref injections match engine names+types "
          f"(v5 PreferenceType cenum)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1:
        RUNTIME = pathlib.Path(sys.argv[1])
    raise SystemExit(main())
