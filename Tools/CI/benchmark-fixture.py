#!/usr/bin/env python3
"""Pinned standard-benchmark fixture builder for Vulpra Simulator benchmark gates.

Two subcommands:

  fetch    --benchmark-dir DIR [--ids id[,id...]] [--force]
           Download each pinned upstream codeload tarball (fixed commit),
           verify its SHA-256 against Configuration/benchmarks.json, and
           extract it safely (top-level repo dir stripped, no path traversal,
           symlink targets confined) into DIR/<id>/. A .vulpra-source.json
           manifest pins the exact commit + hash that produced the tree.

  generate --fixture-dir DIR --benchmark-dir DIR [--ids id[,id...]]
           Emit DIR/runner/<id>.html wrapper pages plus a DIR/index.html
           landing page. Each runner iframes the same-origin pinned sources
           (/benchmarks/<id>/...), starts the benchmark ("auto" via query
           params, or "controller" by calling the benchmark's own JS object
           after its Start control becomes ready), polls the score DOM, and
           writes the score into document.title as
           "VulpraBenchmark <id> score=<text>". The App's
           GeckoView:PageTitleChanged handler logs "Engine title: <title>",
           so the Simulator harness can read the score from the unified log
           stream with no JS injection channel.

The sources themselves are never modified: benchmarks stay byte-identical to
the pinned upstream commits so scores remain comparable across runs. The
wrapper approach keeps automation (auto-start, score capture) outside the
pinned tree.

Portable: pure stdlib (urllib, tarfile, hashlib, json). Network is only used
by `fetch`, and only to hit the pinned codeload URLs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "Configuration" / "benchmarks.json"

COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
SCORE_RE = re.compile(r"^[0-9]+(?:\.[0-9]+)?")

RUNNER_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Vulpra Benchmark Runner: {display_name}</title>
<style>
  html, body {{ margin: 0; height: 100%; background: #14181d; }}
  iframe {{ display: block; width: 100%; height: 100%; border: 0; }}
</style>
</head>
<body>
<iframe id="bench" src="{iframe_src}" title="{display_name}"></iframe>
<script>
(function () {{
  "use strict";
  var CONFIG = {config_json};
  var frame = document.getElementById("bench");
  var started = false;
  var timer = setInterval(function () {{
    var win = null, doc = null;
    try {{ win = frame.contentWindow; doc = frame.contentDocument; }} catch (e) {{ return; }}
    if (!win || !doc) {{ return; }}
    if (!started) {{
      if (CONFIG.start === "controller") {{
        var readyEl = doc.querySelector(CONFIG.startReadySelector);
        if (!readyEl || readyEl.disabled === CONFIG.startReadyEnabled) {{ return; }}
        var target = win;
        var parts = CONFIG.startObject.split(".");
        for (var i = 0; i < parts.length; i++) {{
          target = target[parts[i]];
          if (!target) {{ return; }}
        }}
        var fn = target[CONFIG.startMethod];
        if (typeof fn !== "function") {{ return; }}
        fn.call(target);
      }}
      started = true;
      return;
    }}
    var el = doc.querySelector(CONFIG.scoreSelector);
    var text = el ? (el.textContent || "") : "";
    text = text.replace(/^\\s+|\\s+$/g, "").replace(/\\s+/g, "_");
    if (text && text !== "Error" && text !== "error") {{
      clearInterval(timer);
      document.title = CONFIG.scoreTitlePrefix + text;
    }}
  }}, 500);
}})();
</script>
</body>
</html>
"""

LANDING_TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Vulpra Benchmark Fixture</title>
<style>
  body {{ font: 15px system-ui, -apple-system, sans-serif; margin: 2rem; color: #222; }}
  h1 {{ font-size: 1.2rem; }}
  ul {{ line-height: 1.9; }}
</style>
</head>
<body>
<h1>Vulpra Benchmark Fixture</h1>
<ul>
{links}
</ul>
</body>
</html>
"""


class FixtureError(ValueError):
    pass


def fail(message: str) -> None:
    raise FixtureError(message)


def load_manifest() -> dict[str, object]:
    if not MANIFEST.is_file():
        fail(f"benchmarks manifest missing: {MANIFEST}")
    try:
        value = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"benchmarks manifest is invalid JSON: {error}")
    if not isinstance(value, dict) or value.get("schemaVersion") != 1:
        fail("benchmarks manifest schemaVersion must be 1")
    return value


def select_benchmarks(manifest: dict[str, object], ids: str | None) -> list[dict[str, object]]:
    entries = manifest.get("benchmarks")
    if not isinstance(entries, list) or not entries:
        fail("benchmarks manifest has no benchmarks list")
    by_id = {}
    for entry in entries:
        if not isinstance(entry, dict):
            fail("benchmark entry is not an object")
        benchmark_id = entry.get("id")
        if not isinstance(benchmark_id, str) or not ID_RE.match(benchmark_id):
            fail(f"benchmark id is invalid: {benchmark_id!r}")
        if benchmark_id in by_id:
            fail(f"duplicate benchmark id: {benchmark_id}")
        by_id[benchmark_id] = entry
    if not ids:
        return entries
    wanted = [item.strip() for item in ids.split(",") if item.strip()]
    missing = [item for item in wanted if item not in by_id]
    if missing:
        fail(f"unknown benchmark ids: {', '.join(missing)}")
    return [by_id[item] for item in wanted]


def enabled_by_default_ids(manifest: dict[str, object]) -> list[str]:
    """Ids the benchmark workflow runs by default (enabledByDefault entries)."""
    entries = manifest.get("benchmarks")
    if not isinstance(entries, list) or not entries:
        fail("benchmarks manifest has no benchmarks list")
    return [entry["id"] for entry in entries if entry.get("enabledByDefault") is True]



def validate_entry(entry: dict[str, object]) -> tuple[str, dict[str, object], dict[str, object]]:
    benchmark_id = entry["id"]
    source = entry.get("source")
    run = entry.get("run")
    if not isinstance(source, dict) or not isinstance(run, dict):
        fail(f"benchmark {benchmark_id} source/run must be objects")
    for key in ("repository", "refName", "commit", "archiveURL", "archiveSHA256"):
        if not isinstance(source.get(key), str) or not source[key]:
            fail(f"benchmark {benchmark_id} source.{key} is missing")
    commit = source["commit"]
    if not COMMIT_RE.match(commit):
        fail(f"benchmark {benchmark_id} source.commit is not a 40-hex commit: {commit}")
    if commit not in source["archiveURL"]:
        fail(f"benchmark {benchmark_id} archiveURL does not pin source.commit")
    if not SHA256_RE.match(source["archiveSHA256"]):
        fail(f"benchmark {benchmark_id} source.archiveSHA256 is not 64 hex")
    entry_path = run.get("entry")
    if not isinstance(entry_path, str) or not entry_path or ".." in entry_path.split("/"):
        fail(f"benchmark {benchmark_id} run.entry is invalid: {entry_path!r}")
    start = run.get("start")
    if start not in ("auto", "controller"):
        fail(f"benchmark {benchmark_id} run.start must be auto or controller")

    for key in ("enabledByDefault", "requiresJitBackend"):
        if not isinstance(entry.get(key), bool):
            fail(f"benchmark {benchmark_id} {key} must be a Boolean")
    if entry.get("requiresJitBackend") and not isinstance(entry.get("notes"), str):
        fail(f"benchmark {benchmark_id} notes must explain its JIT-backend requirement")
    for key in ("scoreSelector", "scoreTitlePrefix", "timeoutSeconds"):
        if key not in run:
            fail(f"benchmark {benchmark_id} run.{key} is missing")
    if not isinstance(run["scoreSelector"], str) or not run["scoreSelector"]:
        fail(f"benchmark {benchmark_id} run.scoreSelector is invalid")
    if not isinstance(run["scoreTitlePrefix"], str) or not run["scoreTitlePrefix"]:
        fail(f"benchmark {benchmark_id} run.scoreTitlePrefix is invalid")
    if not isinstance(run["timeoutSeconds"], int) or run["timeoutSeconds"] <= 0:
        fail(f"benchmark {benchmark_id} run.timeoutSeconds must be a positive integer")
    if start == "controller":
        for key in ("startObject", "startMethod", "startReadySelector"):
            if not isinstance(run.get(key), str) or not run[key]:
                fail(f"benchmark {benchmark_id} run.{key} is missing for controller start")
        if not isinstance(run.get("startReadyEnabled"), bool):
            fail(f"benchmark {benchmark_id} run.startReadyEnabled must be a Boolean")
    else:
        for key in ("startObject", "startMethod", "startReadySelector", "startReadyEnabled"):
            if key in run:
                fail(f"benchmark {benchmark_id} run.{key} is only valid for controller start")
    return benchmark_id, source, run


def safe_extract(archive: Path, destination: Path, strip_components: int) -> None:
    """Extract a tar.gz with a fixed leading directory stripped and no escape.

    Rejects absolute member paths, `..` traversal, and symlink/hardlink
    targets that resolve outside the destination. Mirrors the repo's
    secure-tar policy for engine artifacts (Tools/Engine verify scripts).
    """
    destination.mkdir(parents=True, exist_ok=True)
    destination_root = destination.resolve()
    with tarfile.open(archive, "r:gz") as handle:
        members = handle.getmembers()
        for member in members:
            # Validate the FULL member path before stripping the pinned
            # top-level directory: a member such as `../evil` must be rejected
            # even though its first component would be stripped, otherwise the
            # strip itself becomes a traversal vector.
            if Path(member.name).is_absolute():
                fail(f"archive member has an absolute path: {member.name}")
            full_parts = [part for part in Path(member.name).parts if part not in ("", ".")]
            if any(part == ".." for part in full_parts):
                fail(f"archive member escapes the extraction root: {member.name}")
            if len(full_parts) <= strip_components:
                continue  # the pinned top-level repo directory itself
            stripped = full_parts[strip_components:]
            target = (destination / Path(*stripped)).resolve()
            if destination_root != target and destination_root not in target.parents:
                fail(f"archive member resolves outside the extraction root: {member.name}")
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                target.parent.mkdir(parents=True, exist_ok=True)
                with handle.extractfile(member) as reader:
                    payload = reader.read()
                target.write_bytes(payload)
            elif member.issym() or member.islnk():
                link_target = member.linkname
                if os.path.isabs(link_target):
                    fail(f"archive member has an absolute link target: {member.name} -> {link_target}")
                link_parts = [part for part in Path(link_target).parts if part not in ("", ".")]
                if any(part == ".." for part in link_parts):
                    fail(f"archive member link target escapes the extraction root: {member.name} -> {link_target}")
                resolved = (target.parent / link_target).resolve()
                if destination_root not in resolved.parents:
                    fail(f"archive member link target resolves outside the extraction root: {member.name}")
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists() or target.is_symlink():
                    target.unlink()
                target.symlink_to(link_target)
            else:
                fail(f"archive member is an unsupported type: {member.name}")


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download_verified(archive_url: str, expected_sha256: str, benchmark_id: str) -> Path:
    temporary = tempfile.NamedTemporaryFile(prefix=f"vulpra-bench-{benchmark_id}-", suffix=".tar.gz", delete=False)
    temporary.close()
    path = Path(temporary.name)
    try:
        request = urllib.request.Request(archive_url, headers={"User-Agent": "vulpra-benchmark-fixture"})
        with urllib.request.urlopen(request, timeout=120) as response:
            digest = hashlib.sha256()
            with path.open("wb") as output:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    output.write(chunk)
                    digest.update(chunk)
        actual = digest.hexdigest()
        if actual != expected_sha256:
            fail(
                f"benchmark {benchmark_id} archive SHA-256 mismatch: "
                f"expected {expected_sha256}, got {actual}"
            )
        return path
    except BaseException:
        path.unlink(missing_ok=True)
        raise


def cmd_fetch(args: argparse.Namespace) -> int:
    manifest = load_manifest()
    benchmark_dir = Path(args.benchmark_dir)
    for entry in select_benchmarks(manifest, args.ids):
        benchmark_id, source, run = validate_entry(entry)
        target = benchmark_dir / benchmark_id
        entry_path = target / run["entry"]
        if entry_path.is_file() and not args.force:
            print(f"fetch: {benchmark_id} already present at {entry_path}")
            continue
        target.mkdir(parents=True, exist_ok=True)
        archive = download_verified(source["archiveURL"], source["archiveSHA256"], benchmark_id)
        try:
            safe_extract(archive, target, strip_components=1)
        finally:
            archive.unlink(missing_ok=True)
        if not entry_path.is_file():
            fail(
                f"benchmark {benchmark_id} archive did not contain run.entry "
                f"{run['entry']}; expected pinned tree layout changed upstream"
            )
        source_manifest = {
            "schemaVersion": 1,
            "id": benchmark_id,
            "repository": source["repository"],
            "refName": source["refName"],
            "commit": source["commit"],
            "archiveSHA256": source["archiveSHA256"],
            "entry": run["entry"],
        }
        (target / ".vulpra-source.json").write_text(
            json.dumps(source_manifest, indent=2) + "\n", encoding="utf-8"
        )
        print(f"fetch: {benchmark_id} verified and extracted to {target}")
    return 0


def cmd_generate(args: argparse.Namespace) -> int:
    manifest = load_manifest()
    fixture = manifest.get("fixture")
    if not isinstance(fixture, dict):
        fail("benchmarks manifest has no fixture section")
    benchmark_root = fixture.get("benchmarkRoot")
    runner_root = fixture.get("runnerRoot")
    if not isinstance(benchmark_root, str) or not isinstance(runner_root, str):
        fail("benchmarks manifest fixture.benchmarkRoot/runnerRoot are invalid")
    benchmark_dir = Path(args.benchmark_dir)
    fixture_dir = Path(args.fixture_dir)
    links = []
    selected = select_benchmarks(manifest, args.ids)
    for entry in selected:
        benchmark_id, source, run = validate_entry(entry)
        source_dir = benchmark_dir / benchmark_id
        entry_path = source_dir / run["entry"]
        if not entry_path.is_file():
            fail(
                f"benchmark {benchmark_id} entry missing: {entry_path} "
                f"(run `benchmark-fixture.py fetch --benchmark-dir {benchmark_dir}` first)"
            )
        source_manifest_path = source_dir / ".vulpra-source.json"
        if source_manifest_path.is_file():
            try:
                recorded = json.loads(source_manifest_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                recorded = {}
            if recorded.get("commit") != source["commit"]:
                fail(
                    f"benchmark {benchmark_id} source tree is pinned to "
                    f"{recorded.get('commit')!r}, manifest requires {source['commit']}"
                )
        query = run.get("query") or ""
        query_text = f"?{query}" if query else ""
        iframe_src = f"{benchmark_root}/{benchmark_id}/{run['entry']}{query_text}"
        config = {
            "id": benchmark_id,
            "start": run["start"],
            "scoreSelector": run["scoreSelector"],
            "scoreTitlePrefix": run["scoreTitlePrefix"],
        }
        if run["start"] == "controller":
            config["startObject"] = run["startObject"]
            config["startMethod"] = run["startMethod"]
            config["startReadySelector"] = run["startReadySelector"]
            config["startReadyEnabled"] = run["startReadyEnabled"]
        runner_dir = fixture_dir / runner_root.strip("/")
        runner_dir.mkdir(parents=True, exist_ok=True)
        page = RUNNER_TEMPLATE.format(
            display_name=entry.get("displayName", benchmark_id),
            iframe_src=iframe_src,
            config_json=json.dumps(config, sort_keys=True),
        )
        (runner_dir / f"{benchmark_id}.html").write_text(page, encoding="utf-8")
        links.append(
            f'<li><a href="{runner_root}/{benchmark_id}.html">{entry.get("displayName", benchmark_id)}</a></li>'
        )
        print(f"generate: wrote {runner_dir / (benchmark_id + '.html')}")
    fixture_dir.mkdir(parents=True, exist_ok=True)
    (fixture_dir / "index.html").write_text(
        LANDING_TEMPLATE.format(links="\n".join(links)), encoding="utf-8"
    )
    print(f"generate: wrote {fixture_dir / 'index.html'}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    fetch_parser = subparsers.add_parser("fetch", help="download and verify pinned benchmark sources")
    fetch_parser.add_argument("--benchmark-dir", required=True, type=Path)
    fetch_parser.add_argument("--ids", default=None, help="comma-separated benchmark ids")
    fetch_parser.add_argument("--force", action="store_true", help="re-fetch even if present")

    generate_parser = subparsers.add_parser("generate", help="emit same-origin runner pages")
    generate_parser.add_argument("--fixture-dir", required=True, type=Path)
    generate_parser.add_argument("--benchmark-dir", required=True, type=Path)
    generate_parser.add_argument("--ids", default=None, help="comma-separated benchmark ids")

    args = parser.parse_args()
    try:
        if args.command == "fetch":
            return cmd_fetch(args)
        if args.command == "generate":
            return cmd_generate(args)
        fail("no subcommand")
    except (FixtureError, OSError) as error:
        print(f"benchmark-fixture-error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
