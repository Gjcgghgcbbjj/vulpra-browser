#!/usr/bin/env python3
"""EngineStorageClearOptions bit layout vs GeckoView ClearFlags contract.

Cross-checks EngineFeatures.swift option bits against the ClearFlags table of
the actual v5 engine runtime. Evidence is resolved strongest-first: the
packaged GeckoViewStorageController.sys.mjs from the pinned engine artifact
(CI layout .build/engine/runtime/resources, or a local omni.ja), then the
local full source tree. When both are present they must agree, so a packaged
module that drifted from the pinned source is caught.
"""
import re
import sys
from pathlib import Path

from engine_sources import ROOT, read_packaged, read_source, require_snapshot_matches_lock

FEATURES = ROOT / "Engine/VulpraEngineKit/Public/EngineFeatures.swift"

# Gecko ClearFlags -> nsIClearDataService flags.
CLEAR_FLAGS_EXPECT = {
    "COOKIES": 1 << 0,
    "NETWORK_CACHE": 1 << 1,
    "IMAGE_CACHE": 1 << 2,
    "DOM_STORAGES": 1 << 4,
    "AUTH_SESSIONS": 1 << 5,
    "ALL": 1 << 9,
}


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(f"FAIL: {msg}")


def read(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"FAIL: missing {path}")
    return path.read_text(encoding="utf-8")


def eval_shift_expr(expr: str) -> int:
    """Evaluate a Swift expression containing only '1 << N' and '|', e.g.
    'Self(rawValue: 1 << 0)', '(1 << 1) | (1 << 2)', or 'Self(rawValue: 1 << 9)'."""
    value = 0
    for shift in re.findall(r"1\s*<<\s*(\d+)", expr):
        value |= 1 << int(shift)
    return value


def parse_swift_options(swift: str) -> dict:
    values = {}
    # Each option line: public static let <name>[: Self] = <expr>
    for m in re.finditer(r"public static let (\w+)(?::\s*Self)?\s*=\s*(\[?[^;\n]+\]?)", swift):
        name, expr = m.group(1), m.group(2).strip()
        if expr.startswith("["):
            # Set-literal union, e.g. [.cookies, .webStorage, .cache, .authentication]
            members = re.findall(r"\.(\w+)", expr)
            require(all(mem in values for mem in members),
                    f"Swift option {name} union references unknown member(s): {members}")
            values[name] = 0
            for mem in members:
                values[name] |= values[mem]
        else:
            raw = eval_shift_expr(expr)
            require(raw != 0 or "<<" in expr,
                    f"unparsable raw value for Swift option {name}: {expr!r}")
            values[name] = raw
    return values


def parse_gecko_flags(gecko: str) -> dict:
    bits = {}
    # Table rows look like: [\n  // COOKIES\n  1 << 0,\n ...]
    for m in re.finditer(r"//\s*([A-Z_]+)\s*\n\s*(1\s*<<\s*\d+)", gecko):
        bits[m.group(1)] = eval_shift_expr(m.group(2))
    return bits


def resolve_storage_module() -> str:
    """Packaged runtime module first (actual artifact), local source second."""
    problems = []
    packaged = read_packaged("modules/GeckoViewStorageController.sys.mjs")
    source = read_source("mobile/shared/modules/geckoview/GeckoViewStorageController.sys.mjs")
    if packaged is None and source is None:
        raise SystemExit(
            "FAIL: GeckoViewStorageController.sys.mjs not found in packaged "
            "runtime resources or local source tree")
    if packaged is not None and source is not None:
        require(parse_gecko_flags(packaged) == parse_gecko_flags(source),
                "packaged GeckoViewStorageController.sys.mjs ClearFlags table "
                "differs from the pinned source tree copy")
        require_snapshot_matches_lock(problems, "storage clear flags")
        if problems:
            raise SystemExit("FAIL: " + "; ".join(problems))
    return packaged or source


def main() -> int:
    swift = read(FEATURES)
    gecko = resolve_storage_module()

    gecko_bits = parse_gecko_flags(gecko)
    for name, expected in CLEAR_FLAGS_EXPECT.items():
        require(gecko_bits.get(name) == expected,
                f"Gecko ClearFlags table mismatch: {name}={gecko_bits.get(name)} expected={expected}")

    values = parse_swift_options(swift)
    required = ["cookies", "webStorage", "cache", "authentication", "all"]
    missing = [n for n in required if n not in values]
    require(not missing, f"Swift options missing: {missing}; parsed={sorted(values)}")

    require(values["cookies"] == gecko_bits["COOKIES"],
            f"cookies bit mismatch: Swift={values['cookies']} Gecko={gecko_bits['COOKIES']}")
    require(values["webStorage"] == gecko_bits["DOM_STORAGES"],
            f"webStorage bit mismatch: Swift={values['webStorage']} Gecko={gecko_bits['DOM_STORAGES']}")
    require(values["cache"] == (gecko_bits["NETWORK_CACHE"] | gecko_bits["IMAGE_CACHE"]),
            f"cache bit mismatch: Swift={values['cache']} expected={gecko_bits['NETWORK_CACHE'] | gecko_bits['IMAGE_CACHE']}")
    require(values["authentication"] == gecko_bits["AUTH_SESSIONS"],
            f"authentication bit mismatch: Swift={values['authentication']} Gecko={gecko_bits['AUTH_SESSIONS']}")
    require(values["all"] == gecko_bits["ALL"],
            f"all bit mismatch: Swift={values['all']} Gecko={gecko_bits['ALL']}")
    print(f"PASS: EngineStorageClearOptions matches GeckoView ClearFlags "
          f"(cookies={values['cookies']}, webStorage={values['webStorage']}, "
          f"cache={values['cache']}, authentication={values['authentication']}, all={values['all']})")
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1:
        FEATURES = Path(sys.argv[1])
    raise SystemExit(main())
