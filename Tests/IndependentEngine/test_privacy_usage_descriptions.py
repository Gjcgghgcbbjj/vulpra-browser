#!/usr/bin/env python3
"""Draft (NOT committed): App/Info.plist must declare mic + location usage keys.

Prepared during gate 31244916221 wait. When the gate goes green this becomes
Tests/IndependentEngine/test_privacy_usage_descriptions.py together with the
App/Info.plist fix (A54). Fails today (keys missing); passes after fix.
"""
import pathlib
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def find_root() -> Path:
    p = Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "App" / "Info.plist").is_file():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from " + str(Path(__file__).resolve().parent))


ROOT = find_root()
PLIST = ROOT / "App/Info.plist"

REQUIRED = {
    "NSMicrophoneUsageDescription": "getUserMedia({audio:true}) / capture_access.mm",
    "NSLocationWhenInUseUsageDescription": "navigator.geolocation / GeolocationSystemUIKit.mm",
}


def main() -> int:
    if not PLIST.is_file():
        raise SystemExit(f"FAIL: missing {PLIST}")
    try:
        root = ET.parse(PLIST).getroot()
    except ET.ParseError as e:
        raise SystemExit(f"FAIL: {PLIST} is not valid XML: {e}")
    if root.tag != "plist":
        raise SystemExit("FAIL: not a plist document")
    missing = []
    for key, why in REQUIRED.items():
        # Walk for <key>NAME</key> anywhere in the dict tree.
        found = any(elem.tag == "key" and (elem.text or "").strip() == key
                    for elem in root.iter())
        if not found:
            missing.append(f"{key} ({why})")
    if missing:
        raise SystemExit("FAIL: missing required usage-description keys:\n  " + "\n  ".join(missing))
    print("PASS: App/Info.plist declares NSMicrophoneUsageDescription and NSLocationWhenInUseUsageDescription")
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1:
        PLIST = pathlib.Path(sys.argv[1])
    raise SystemExit(main())
