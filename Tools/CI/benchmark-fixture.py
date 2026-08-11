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
           Emit DIR/benchmarks/<id>/ (a byte-identical copy of each verified
           pinned source tree) plus a DIR/index.html landing page. The run.entry
           page of each copy gets a small same-document probe appended before
           </body>. The probe starts the benchmark ("auto" via the run.query URL
           params, or "controller" by calling the benchmark's own JS object once
           its ready condition holds), polls the score DOM, and writes
           "VulpraBenchmark <id> progress=.../score=<text>" into
           document.title. The App's GeckoView:PageTitleChanged handler logs
           "Engine title: <title>", so the Simulator harness can read progress
           and score from the unified log stream with no JS injection channel.

           The served fixture is the TOP-LEVEL benchmark entry page itself
           (no wrapper iframe): the fixture server in benchmark-ci.yml serves
           the whole generated fixture dir, so /benchmarks/<id>/... resolves to
           the copied tree. Each copy carries a .vulpra-fixture.json manifest
           recording sourceCommit + entry SHA-256s + probe SHA-256 so the
           rewrite is fully provenance-pinned.

  url      --ids id[,id...]
           Print the fixture URL path (benchmarkRoot + entry + run.query) for
           each selected benchmark, one per line. Used by benchmark-ci.yml to
           build the App initial URL.

The pinned sources are never modified in place: `fetch` verifies the archive
SHA-256, `generate` copies the verified tree into the fixture and appends only
the probe (a pure reporting/controller shim that does not touch benchmark
timing code), and .vulpra-fixture.json pins the hashes. Scores remain
comparable across runs.

Portable: pure stdlib (urllib, tarfile, hashlib, json, shutil). Network is
only used by `fetch`, and only to hit the pinned codeload URLs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
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

ENTRY_PROBE_SCRIPT = """<script>
(function () {
  "use strict";
  var CONFIG = __CONFIG_JSON__;
  var lastProgress = "";
  var t0 = Date.now();
  var started = false;
  var done = false;
  function tick() {
    if (!started) {
      if (CONFIG.start === "controller") {
        var ready = false;
        if (CONFIG.startReadyPath) {
          var target = window;
          var parts = CONFIG.startReadyPath.split(".");
          ready = true;
          for (var i = 0; i < parts.length; i++) {
            if (!target) { ready = false; break; }
            target = target[parts[i]];
          }
          if (ready && target !== CONFIG.startReadyValue) { ready = false; }
        } else if (CONFIG.startReadySelector) {
          var readyEl = document.querySelector(CONFIG.startReadySelector);
          if (!readyEl || readyEl.disabled === CONFIG.startReadyEnabled) { ready = false; }
          else { ready = true; }
        }
        if (!ready) { return; }
        var target2 = window;
        var parts2 = CONFIG.startObject.split(".");
        for (var j = 0; j < parts2.length; j++) {
          target2 = target2[parts2[j]];
          if (!target2) { return; }
        }
        var fn = target2[CONFIG.startMethod];
        if (typeof fn !== "function") { return; }
        started = true;
        fn.call(target2);
      } else {
        started = true;
      }
    }
    if (done) { return; }
    if (CONFIG.progress) {
      var bits = [];
      var labelEl = document.querySelector(CONFIG.progress.labelSelector);
      var textEl = document.querySelector(CONFIG.progress.textSelector);
      var barEl = document.querySelector(CONFIG.progress.barSelector);
      var label = labelEl ? (labelEl.textContent || "") : "";
      var text = textEl ? (textEl.textContent || "") : "";
      if (label) { bits.push(label.replace(/\\s+/g, "_")); }
      if (text) { bits.push(text.replace(/\\s+/g, "_")); }
      if (barEl && barEl.max != null && barEl.value != null) {
        bits.push("bar=" + barEl.value + "/" + barEl.max);
      }
      if (bits.length > 0) {
        bits.push("elapsed=" + Math.floor((Date.now() - t0) / 1000) + "s");
        var progress = "progress=" + bits.join("|");
        if (progress !== lastProgress) {
          lastProgress = progress;
          document.title = CONFIG.progressTitlePrefix + progress;
        }
      }
    }
    var el = document.querySelector(CONFIG.scoreSelector);
    var text = el ? (el.textContent || "") : "";
    text = text.replace(/^\\s+|\\s+$/g, "").replace(/\\s+/g, "_");
    if (text && text !== "Error" && text !== "error") {
      done = true;
      document.title = CONFIG.scoreTitlePrefix + text;
    }
  }
  setInterval(tick, 500);
})();
</script>
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
    progress = run.get("progress")
    if progress is not None:
        if not isinstance(progress, dict):
            fail(f"benchmark {benchmark_id} run.progress must be an object")
        for key in ("labelSelector", "textSelector", "barSelector"):
            value = progress.get(key)
            if not isinstance(value, str) or not value or not value.startswith("#"):
                fail(f"benchmark {benchmark_id} run.progress.{key} "
                     "must be a CSS selector starting with #")
    if not isinstance(run["scoreSelector"], str) or not run["scoreSelector"]:
        fail(f"benchmark {benchmark_id} run.scoreSelector is invalid")
    if not isinstance(run["scoreTitlePrefix"], str) or not run["scoreTitlePrefix"]:
        fail(f"benchmark {benchmark_id} run.scoreTitlePrefix is invalid")
    if not isinstance(run["timeoutSeconds"], int) or run["timeoutSeconds"] <= 0:
        fail(f"benchmark {benchmark_id} run.timeoutSeconds must be a positive integer")
    if start == "controller":
        for key in ("startObject", "startMethod"):
            if not isinstance(run.get(key), str) or not run[key]:
                fail(f"benchmark {benchmark_id} run.{key} is missing for controller start")
        has_selector_ready = "startReadySelector" in run or "startReadyEnabled" in run
        has_path_ready = "startReadyPath" in run or "startReadyValue" in run
        if has_selector_ready == has_path_ready:
            fail(f"benchmark {benchmark_id} run must use exactly one ready mechanism: "
                 "startReadySelector+startReadyEnabled or startReadyPath+startReadyValue")
        if has_path_ready:
            ready_path = run.get("startReadyPath")
            if not isinstance(ready_path, str) or not ready_path \
                    or not all(part.isidentifier() for part in ready_path.split(".")):
                fail(f"benchmark {benchmark_id} run.startReadyPath must be a dotted identifier path")
            if not isinstance(run.get("startReadyValue"), bool):
                fail(f"benchmark {benchmark_id} run.startReadyValue must be a Boolean")
        else:
            if not isinstance(run.get("startReadySelector"), str) or not run["startReadySelector"]:
                fail(f"benchmark {benchmark_id} run.startReadySelector is missing for controller start")
            if not isinstance(run.get("startReadyEnabled"), bool):
                fail(f"benchmark {benchmark_id} run.startReadyEnabled must be a Boolean")
    else:
        for key in ("startObject", "startMethod", "startReadySelector",
                    "startReadyEnabled", "startReadyPath", "startReadyValue"):
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


def sha256_of_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def inject_probe(payload: bytes, probe: str) -> bytes:
    """Append the reporting probe before </body> (case-insensitive), else at EOF."""
    marker = b"</body>"
    index = payload.lower().rfind(marker)
    probe_bytes = probe.encode("utf-8")
    if index == -1:
        return payload + probe_bytes
    return payload[:index] + probe_bytes + payload[index:]


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
    if not isinstance(benchmark_root, str) or not benchmark_root.startswith("/"):
        fail("benchmarks manifest fixture.benchmarkRoot is invalid")
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
        entry_url = f"{benchmark_root}/{benchmark_id}/{run['entry']}{query_text}"
        config = {
            "id": benchmark_id,
            "start": run["start"],
            "scoreSelector": run["scoreSelector"],
            "scoreTitlePrefix": run["scoreTitlePrefix"],
        }
        if run.get("progress"):
            config["progress"] = run["progress"]
            config["progressTitlePrefix"] = f"VulpraBenchmark {benchmark_id} progress="
        if run["start"] == "controller":
            config["startObject"] = run["startObject"]
            config["startMethod"] = run["startMethod"]
            if "startReadyPath" in run:
                config["startReadyPath"] = run["startReadyPath"]
                config["startReadyValue"] = run["startReadyValue"]
            else:
                config["startReadySelector"] = run["startReadySelector"]
                config["startReadyEnabled"] = run["startReadyEnabled"]
        probe = ENTRY_PROBE_SCRIPT.replace(
            "__CONFIG_JSON__", json.dumps(config, sort_keys=True)
        )
        target_dir = fixture_dir / benchmark_root.strip("/") / benchmark_id
        if target_dir.exists():
            shutil.rmtree(target_dir)
        shutil.copytree(source_dir, target_dir)
        target_entry = target_dir / run["entry"]
        original = target_entry.read_bytes()
        patched = inject_probe(original, probe)
        target_entry.write_bytes(patched)
        provenance = {
            "schemaVersion": 1,
            "id": benchmark_id,
            "repository": source["repository"],
            "refName": source["refName"],
            "commit": source["commit"],
            "archiveSHA256": source["archiveSHA256"],
            "entry": run["entry"],
            "sourceEntrySHA256": sha256_of_bytes(original),
            "fixtureEntrySHA256": sha256_of_bytes(patched),
            "probeScriptSHA256": sha256_of_bytes(probe.encode("utf-8")),
        }
        (target_dir / ".vulpra-fixture.json").write_text(
            json.dumps(provenance, indent=2) + "\n", encoding="utf-8"
        )
        links.append(
            f'<li><a href="{entry_url}">{entry.get("displayName", benchmark_id)}</a></li>'
        )
        print(
            f"generate: wrote {target_entry} "
            f"(entry sha256 {provenance['fixtureEntrySHA256']})"
        )
    fixture_dir.mkdir(parents=True, exist_ok=True)
    (fixture_dir / "index.html").write_text(
        LANDING_TEMPLATE.format(links="\n".join(links)), encoding="utf-8"
    )
    print(f"generate: wrote {fixture_dir / 'index.html'}")
    return 0


def cmd_url(args: argparse.Namespace) -> int:
    """Print the fixture URL path for each selected benchmark, one per line."""
    manifest = load_manifest()
    fixture = manifest.get("fixture")
    benchmark_root = fixture.get("benchmarkRoot") if isinstance(fixture, dict) else None
    if not isinstance(benchmark_root, str) or not benchmark_root.startswith("/"):
        fail("benchmarks manifest fixture.benchmarkRoot is invalid")
    for benchmark_id, _source, run in (
        validate_entry(entry) for entry in select_benchmarks(manifest, args.ids)
    ):
        query = run.get("query") or ""
        query_text = f"?{query}" if query else ""
        print(f"{benchmark_root}/{benchmark_id}/{run['entry']}{query_text}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    fetch_parser = subparsers.add_parser("fetch", help="download and verify pinned benchmark sources")
    fetch_parser.add_argument("--benchmark-dir", required=True, type=Path)
    fetch_parser.add_argument("--ids", default=None, help="comma-separated benchmark ids")
    fetch_parser.add_argument("--force", action="store_true", help="re-fetch even if present")

    generate_parser = subparsers.add_parser(
        "generate", help="emit the served fixture (copied benchmark trees + probe)"
    )
    generate_parser.add_argument("--fixture-dir", required=True, type=Path)
    generate_parser.add_argument("--benchmark-dir", required=True, type=Path)
    generate_parser.add_argument("--ids", default=None, help="comma-separated benchmark ids")

    url_parser = subparsers.add_parser("url", help="print benchmark entry URL paths")
    url_parser.add_argument("--ids", default=None, help="comma-separated benchmark ids")
    url_parser.add_argument("--benchmark", dest="ids", default=None,
                            help="single benchmark id (alias for --ids)")

    args = parser.parse_args()
    try:
        if args.command == "fetch":
            return cmd_fetch(args)
        if args.command == "generate":
            return cmd_generate(args)
        if args.command == "url":
            return cmd_url(args)
        fail("no subcommand")
    except (FixtureError, OSError) as error:
        print(f"benchmark-fixture-error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
