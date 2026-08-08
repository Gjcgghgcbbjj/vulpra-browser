#!/usr/bin/env python3
"""Draft (NOT committed): GeckoView:Preferences:SetPref channel contract.

Prepared during gate 31244916221 wait (annex 67, bug C2). The App injects
prefs through the shared GeckoViewPreferences JS handler, which matches types
against Ci.nsIPrefBranch constants of the v5 engine. In this Firefox version
the PreferenceType cenum is PREF_INVALID=0 / PREF_STRING=32 / PREF_INT=64 /
PREF_BOOL=128 (NOT the legacy 0/1/2). This test cross-checks every injected
pref name and type constant against the engine source (StaticPrefList.yaml /
all.js / mobile.js / C++ readers):

- pref name must exist verbatim in the engine source (catches typos like
  `startup-timeout-ms` vs `startup_timeout_ms`);
- type must be 32/64/128 AND match the engine-declared pref type.

Fails today on HEAD (RDD injection uses type 1 and the hyphenated name);
passes after the corrected stack (rdd-pref-fix + A57 + A39 + C1).
"""
import pathlib
import re
import sys
from pathlib import Path

PREF_INVALID, PREF_STRING, PREF_INT, PREF_BOOL = 0, 32, 64, 128


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
GECKO = ROOT / ".build/gecko-source-full-patched-20260730"
STATIC = GECKO / "modules/libpref/init/StaticPrefList.yaml"
ALLJS = GECKO / "modules/libpref/init/all.js"
MOBILEJS = GECKO / "mobile/ios/app/mobile.js"
RUNTIME = ROOT / "Engine/VulpraEngineKit/Internal/Runtime/VulpraEngineRuntime.swift"


def static_type(pref: str):
    """Return engine type ('bool'|'int'|'string'|None) from StaticPrefList.yaml."""
    s = STATIC.read_text(encoding="utf-8")
    m = re.search(r"- name: " + re.escape(pref) + r"\n(?:.*\n)*?\s+type: (\S+)", s)
    if not m:
        return None
    t = m.group(1).lower()
    if "bool" in t:
        return "bool"
    if "int" in t:
        return "int"
    if "string" in t:
        return "string"
    return None


def js_default_type(pref: str):
    """Return type from all.js/mobile.js pref() default value."""
    for f in (ALLJS, MOBILEJS):
        if not f.is_file():
            continue
        s = f.read_text(encoding="utf-8")
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
    """Return type from C++ readers (Preferences::GetBool/GetInt/GetString)."""
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
    import subprocess
    r = subprocess.run(
        ["rg", "-l", "-F", needle, str(GECKO), "-g", "*.{cpp,h,mm,js,mjs,yaml}"],
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
    """Return GeckoViewPreferences.sys.mjs from the packaged omni.ja (actual runtime)."""
    import zipfile
    for candidate in sorted(ROOT.glob(".build/*/runtime/resources/omni.ja")):
        if not candidate.is_file():
            continue
        with zipfile.ZipFile(candidate) as z:
            names = z.namelist()
            for want in ("modules/GeckoViewPreferences.sys.mjs",
                         "modules/geckoview/GeckoViewPreferences.sys.mjs"):
                if want in names:
                    return z.read(want).decode("utf-8", "replace")
    return ""


def verify_packaged_handler(problems: list) -> None:
    handler = packaged_preferences_handler()
    if not handler:
        problems.append("packaged omni.ja GeckoViewPreferences.sys.mjs not found")
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


def main() -> int:
    if not RUNTIME.is_file():
        raise SystemExit(f"FAIL: missing {RUNTIME}")
    if not STATIC.is_file() or not ALLJS.is_file():
        raise SystemExit(f"FAIL: gecko source missing ({GECKO})")
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

        # 1) pref name must exist verbatim in engine source
        found = (static_type(pref) is not None or js_default_type(pref) is not None
                 or run_grep(pref))
        if not found:
            problems.append(f"{pref}: pref name NOT found verbatim in engine source")

        # 2) type must match engine-declared type
        eng = static_type(pref) or js_default_type(pref) or cpp_reader_type(pref)
        if eng is None:
            problems.append(f"{pref}: cannot determine engine type from source")
        elif typ != expected_constant(eng):
            problems.append(
                f"{pref}: type {typ} != expected {expected_constant(eng)} (engine {eng})"
            )

    verify_packaged_handler(problems)

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
