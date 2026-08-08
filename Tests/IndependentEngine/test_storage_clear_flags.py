#!/usr/bin/env python3
"""Draft: EngineStorageClearOptions bit layout vs GeckoView ClearFlags contract.

Prepared during gate 31244916221 wait (read-only; NOT yet committed).
When the lifecycle gate goes green, this becomes
Tests/IndependentEngine/test_storage_clear_flags.py together with the
EngineFeatures.swift bit-value fix (see .build/storage-clear-flags-fix.patch).
"""
import pathlib
import re
import sys
from pathlib import Path


def find_root() -> Path:
    """Locate the worktree root regardless of where this file lives
    (draft sits in .build/, committed copy will sit in Tests/IndependentEngine/)."""
    p = Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "Engine" / "VulpraEngineKit" / "Public" / "EngineFeatures.swift").is_file():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from " + str(Path(__file__).resolve().parent))


ROOT = find_root()
FEATURES = ROOT / "Engine/VulpraEngineKit/Public/EngineFeatures.swift"
STORAGE = ROOT / ".build/gecko-source-full-patched-20260730/mobile/shared/modules/geckoview/GeckoViewStorageController.sys.mjs"

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


def main() -> int:
    swift = read(FEATURES)
    gecko = read(STORAGE)

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
        FEATURES = pathlib.Path(sys.argv[1])
    raise SystemExit(main())
