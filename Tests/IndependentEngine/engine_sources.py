#!/usr/bin/env python3
"""Shared engine-evidence resolution for IndependentEngine contract tests.

The contract tests cross-check App/EngineKit code against the *actual v5
engine* (packed runtime resources + pinned source snapshot). The full Firefox
source tree is only present in local builds
(.build/gecko-source-full-patched-20260730); CI only has the packaged runtime
resources extracted from the pinned engine artifact
(.build/engine/runtime/resources, i.e. the exploded omni.ja content) plus
whatever contract data is checked into the repository.

Evidence is resolved strongest-first in this order:

1. packaged runtime resources directory (.build/engine/runtime/resources);
2. packaged omni.ja archive (first .build/*/runtime/resources/omni.ja);
3. local full source tree (.build/gecko-source-full-patched-20260730);
4. checked-in engine contract snapshot
   (Tests/IndependentEngine/data/engine-contract-snapshot.json), accepted only
   when its provenance matches Configuration/engine-artifact-lock.json.
"""
import json
import zipfile
from pathlib import Path


def find_root() -> Path:
    p = Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "Engine" / "VulpraEngineKit").is_dir():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from "
                     + str(Path(__file__).resolve().parent))


ROOT = find_root()
LOCK_PATH = ROOT / "Configuration/engine-artifact-lock.json"
SNAPSHOT_PATH = (ROOT / "Tests/IndependentEngine/data"
                 / "engine-contract-snapshot.json")


def lock() -> dict:
    if not LOCK_PATH.is_file():
        return {}
    try:
        return json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def pinned() -> dict:
    """Provenance of the pinned engine artifact (device side)."""
    data = lock()
    device = data.get("device") or {}
    return {
        "firefoxCommit": device.get("sourceCommit"),
        "patchSetSHA256": device.get("patchSetSHA256"),
        "producerHeadSha": data.get("producerHeadSha"),
    }


def snapshot() -> dict:
    if not SNAPSHOT_PATH.is_file():
        return {}
    try:
        return json.loads(SNAPSHOT_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def snapshot_matches_lock() -> bool:
    prov = (snapshot().get("provenance") or {})
    pin = pinned()
    return all(prov.get(k) == v for k, v in pin.items() if v)


def local_source_tree() -> Path:
    p = ROOT / ".build/gecko-source-full-patched-20260730"
    return p if p.is_dir() else None


def packaged_resources_dir() -> Path:
    """Exploded runtime resources dir (CI layout)."""
    candidates = [
        ROOT / ".build/engine/runtime/resources",
    ]
    for c in candidates:
        if c.is_dir() and (c / "greprefs.js").is_file():
            return c
    return None


def omni_ja_candidates():
    if packaged_resources_dir() and (packaged_resources_dir() / "omni.ja").is_file():
        yield packaged_resources_dir() / "omni.ja"
    for p in sorted((ROOT / ".build").glob("*/runtime/resources/omni.ja")):
        if p.is_file():
            yield p


def read_packaged(rel: str):
    """Read rel ('modules/X.sys.mjs', 'greprefs.js', ...) from the packaged
    runtime: exploded resources dir first, then omni.ja archives."""
    d = packaged_resources_dir()
    if d is not None:
        f = d / rel
        if f.is_file():
            return f.read_text(encoding="utf-8")
    for omni in omni_ja_candidates():
        try:
            with zipfile.ZipFile(omni) as z:
                names = z.namelist()
                if rel in names:
                    return z.read(rel).decode("utf-8", "replace")
        except (OSError, zipfile.BadZipFile):
            continue
    return None


def read_source(rel: str):
    """Read rel from the local full source tree, or None if absent."""
    tree = local_source_tree()
    if tree is None:
        return None
    f = tree / rel
    if not f.is_file():
        return None
    return f.read_text(encoding="utf-8")


def require_snapshot_matches_lock(problems: list, label: str) -> None:
    """Append a problem unless the snapshot provenance equals the lock."""
    if not snapshot():
        problems.append(f"{label}: no checked-in engine contract snapshot")
    elif not snapshot_matches_lock():
        problems.append(
            f"{label}: engine-contract-snapshot.json provenance does not match "
            f"engine-artifact-lock.json (pinned={pinned()})")
