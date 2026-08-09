#!/usr/bin/env python3
"""Portable contracts for the standard-benchmark gate infrastructure.

Verifies the pinned benchmark manifest (Configuration/benchmarks.json), the
fixture generator (Tools/CI/benchmark-fixture.py fetch/generate), the secure
tar extraction policy, the Simulator benchmark summarizer
(Tools/CI/summarize-benchmark.py), the App title evidence log, and the
harness wiring (Tools/CI/run-simulator-benchmark.sh). When `node` is
available, it also executes the generated runner-page JavaScript against a
DOM mock to prove auto/controller start and score -> page-title capture.

Pure stdlib; no network is touched. Benchmark sources are synthesized as
minimal trees (entry files + .vulpra-source.json) unless the real pinned
trees are already staged under .build/benchmarks.
"""

from __future__ import annotations

import copy
import io
import json
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GENERATOR = ROOT / "Tools" / "CI" / "benchmark-fixture.py"
SUMMARIZER = ROOT / "Tools" / "CI" / "summarize-benchmark.py"
HARNESS = ROOT / "Tools" / "CI" / "run-simulator-benchmark.sh"
VALIDATOR = ROOT / "Tools" / "CI" / "validate-benchmark-selection.py"
WORKFLOW = ROOT / ".github" / "workflows" / "benchmark-ci.yml"
MANIFEST_PATH = ROOT / "Configuration" / "benchmarks.json"

import importlib.util

_spec = importlib.util.spec_from_file_location("vulpra_benchmark_fixture", GENERATOR)
benchmark_fixture = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(benchmark_fixture)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def load_manifest() -> dict[str, object]:
    manifest = benchmark_fixture.load_manifest()
    require(manifest.get("schemaVersion") == 1, "benchmarks.json schemaVersion must be 1")
    device = manifest.get("device")
    require(isinstance(device, dict) and device.get("family") == "ipad",
            "benchmarks.json device.family must be ipad")
    fixture = manifest.get("fixture")
    require(isinstance(fixture, dict)
            and fixture.get("benchmarkRoot") == "/benchmarks"
            and fixture.get("runnerRoot") == "/runner",
            "benchmarks.json fixture roots must be /benchmarks and /runner")
    return manifest


def check_manifest_entries(manifest: dict[str, object]) -> None:
    entries = manifest["benchmarks"]
    require(len(entries) >= 1, "benchmarks.json has no benchmarks")
    for entry in entries:
        benchmark_id, source, run = benchmark_fixture.validate_entry(entry)
        require(source["commit"] in source["archiveURL"],
                f"{benchmark_id} archiveURL must pin its commit")
        require(run["start"] in ("auto", "controller"),
                f"{benchmark_id} start mode must be auto or controller")
        require(run["timeoutSeconds"] >= 60,
                f"{benchmark_id} timeoutSeconds should be at least 60")
        require(run["scoreTitlePrefix"].startswith("VulpraBenchmark "),
                f"{benchmark_id} scoreTitlePrefix must start with VulpraBenchmark")
        require(run["scoreSelector"].startswith("#"),
                f"{benchmark_id} scoreSelector must be a CSS id/class selector")
        require(isinstance(entry.get("enabledByDefault"), bool)
                and isinstance(entry.get("requiresJitBackend"), bool),
                f"{benchmark_id} must declare enabledByDefault and requiresJitBackend Booleans")
        if benchmark_id == "jetstream":
            require(entry.get("enabledByDefault") is False
                    and entry.get("requiresJitBackend") is True,
                    "jetstream must be requiresJitBackend and NOT enabledByDefault "
                    "(wasm suite cannot run on the JIT-disabled v5 engine)")
            require(isinstance(entry.get("notes"), str) and len(entry["notes"]) > 80,
                    "jetstream notes must document its JIT-backend/wasm dependency")
        else:
            require(entry.get("enabledByDefault") is True
                    and entry.get("requiresJitBackend") is False,
                    f"{benchmark_id} must be enabledByDefault without a JIT-backend requirement")


def make_synthetic_sources(benchmark_dir: Path, manifest: dict[str, object]) -> None:
    """Create minimal entry-file trees for every pinned benchmark."""
    for entry in manifest["benchmarks"]:
        benchmark_id, source, run = benchmark_fixture.validate_entry(entry)
        target = benchmark_dir / benchmark_id
        entry_file = target / run["entry"]
        entry_file.parent.mkdir(parents=True, exist_ok=True)
        entry_file.write_text(
            f"<!doctype html><html><head><title>{benchmark_id}</title></head>"
            f"<body data-entry={benchmark_id}></body></html>\n",
            encoding="utf-8",
        )
        (target / ".vulpra-source.json").write_text(
            json.dumps({
                "schemaVersion": 1,
                "id": benchmark_id,
                "repository": source["repository"],
                "refName": source["refName"],
                "commit": source["commit"],
                "archiveSHA256": source["archiveSHA256"],
                "entry": run["entry"],
            }, indent=2) + "\n",
            encoding="utf-8",
        )


def run_generator(args: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(GENERATOR), *args], cwd=cwd, text=True,
        capture_output=True, check=False,
    )


def check_generate(manifest: dict[str, object]) -> None:
    with tempfile.TemporaryDirectory(prefix="vulpra-bench-gen-") as temporary:
        base = Path(temporary)
        sources = base / "sources"
        make_synthetic_sources(sources, manifest)
        fixture = base / "fixture"
        result = run_generator([
            "generate", "--fixture-dir", str(fixture), "--benchmark-dir", str(sources),
        ], ROOT)
        require(result.returncode == 0, f"generate failed: {result.stderr}")
        ids = [entry["id"] for entry in manifest["benchmarks"]]
        for benchmark_id in ids:
            runner = fixture / "runner" / f"{benchmark_id}.html"
            require(runner.is_file(), f"runner page missing: {runner}")
            text = runner.read_text(encoding="utf-8")
            require("iframe" in text and 'id="bench"' in text,
                    f"{benchmark_id} runner page has no bench iframe")
            require("http://" not in text, f"{benchmark_id} runner page leaks an absolute URL")
            require("eval(" not in text and "new Function" not in text,
                    f"{benchmark_id} runner page must not use eval")
            require('document.title = CONFIG.scoreTitlePrefix + text' in text,
                    f"{benchmark_id} runner page must publish the score via title")
        # Speedometer3 gate must carry the representative subset query and progress wiring.
        speedometer = fixture / "runner" / "speedometer3.html"
        speedometer_text = speedometer.read_text(encoding="utf-8")
        require('"progress": {' in speedometer_text,
                "speedometer3 runner page missing progress config")
        require('"progressTitlePrefix": "VulpraBenchmark speedometer3 progress="' in speedometer_text,
                "speedometer3 runner page missing progress title prefix")
        require("suites=TodoMVC-JavaScript-ES5,Editor-CodeMirror,Charts-chartjs,Perf-Dashboard" in speedometer_text,
                "speedometer3 iframe src must carry the representative suites query")

        require((fixture / "index.html").is_file(), "landing index.html missing")
        landing = (fixture / "index.html").read_text(encoding="utf-8")
        for benchmark_id in ids:
            require(f"/runner/{benchmark_id}.html" in landing,
                    f"landing page missing link to {benchmark_id}")

        # MotionMark runner must wire the controller start path.
        motion = fixture / "runner" / "motionmark.html"
        motion_text = motion.read_text(encoding="utf-8")
        require('"startObject": "benchmarkController"' in motion_text,
                "motionmark runner missing startObject")
        require('"startMethod": "startBenchmark"' in motion_text,
                "motionmark runner missing startMethod")
        require('"startReadyPath": "benchmarkController.frameRateDetectionComplete"' in motion_text,
                "motionmark runner missing frameRateDetectionComplete ready path")
        require('"startReadyValue": true' in motion_text,
                "motionmark runner missing startReadyValue true")
        require('"startReadySelector": "#start-button"' not in motion_text,
                "motionmark must not wait for the portrait-disabled Start button")

        # A stale source tree pinned to a different commit must be rejected.
        stale = base / "stale"
        make_synthetic_sources(stale, manifest)
        stale_manifest = stale / "speedometer3" / ".vulpra-source.json"
        recorded = json.loads(stale_manifest.read_text(encoding="utf-8"))
        recorded["commit"] = "0" * 40
        stale_manifest.write_text(json.dumps(recorded), encoding="utf-8")
        result = run_generator([
            "generate", "--fixture-dir", str(base / "stale-fixture"),
            "--benchmark-dir", str(stale), "--ids", "speedometer3",
        ], ROOT)
        require(result.returncode != 0 and "pinned to" in result.stderr,
                "generate must reject a source tree pinned to the wrong commit")

        # A missing entry must be rejected.
        missing = base / "missing"
        make_synthetic_sources(missing, manifest)
        (missing / "speedometer3" / "index.html").unlink()
        result = run_generator([
            "generate", "--fixture-dir", str(base / "missing-fixture"),
            "--benchmark-dir", str(missing), "--ids", "speedometer3",
        ], ROOT)
        require(result.returncode != 0 and "entry missing" in result.stderr,
                "generate must reject a source tree missing the entry file")


def check_safe_extract() -> None:
    def build_tar(members: list[tuple[str, str | None, str | None]]) -> Path:
        # members: (name, payload, link_target)
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode="w:gz") as handle:
            for name, payload, link_target in members:
                if link_target is not None:
                    info = tarfile.TarInfo(name)
                    info.type = tarfile.SYMTYPE
                    info.linkname = link_target
                    handle.addfile(info)
                else:
                    info = tarfile.TarInfo(name)
                    data = payload.encode("utf-8") if payload is not None else b""
                    info.size = len(data)
                    handle.addfile(info, io.BytesIO(data))
        path = Path(tempfile.mkstemp(prefix="vulpra-tar-", suffix=".tar.gz")[1])
        path.write_bytes(buffer.getvalue())
        return path

    benign = build_tar([
        ("Bench-1111111111111111111111111111111111111111/README.md", "hello", None),
        ("Bench-1111111111111111111111111111111111111111/sub/index.html", "<html></html>", None),
    ])
    try:
        destination = Path(tempfile.mkdtemp(prefix="vulpra-extract-"))
        benchmark_fixture.safe_extract(benign, destination, strip_components=1)
        require((destination / "README.md").is_file(), "safe_extract lost the stripped file")
        require((destination / "sub" / "index.html").is_file(),
                "safe_extract lost the nested entry")
    finally:
        benign.unlink(missing_ok=True)

    traversal = build_tar([("../evil", "boom", None)])
    try:
        destination = Path(tempfile.mkdtemp(prefix="vulpra-extract-"))
        try:
            benchmark_fixture.safe_extract(traversal, destination, strip_components=1)
            raise SystemExit("FAIL: traversal archive was extracted")
        except benchmark_fixture.FixtureError as error:
            require("escapes" in str(error), f"traversal error is unclear: {error}")
    finally:
        traversal.unlink(missing_ok=True)

    absolute = build_tar([("/tmp/vulpra-evil", "boom", None)])
    try:
        destination = Path(tempfile.mkdtemp(prefix="vulpra-extract-"))
        try:
            benchmark_fixture.safe_extract(absolute, destination, strip_components=1)
            raise SystemExit("FAIL: absolute-path archive was extracted")
        except benchmark_fixture.FixtureError:
            pass
    finally:
        absolute.unlink(missing_ok=True)

    symlink_escape = build_tar([
        ("Bench-1111111111111111111111111111111111111111/ok.txt", "ok", None),
        ("Bench-1111111111111111111111111111111111111111/evil", None, "../../../../etc/passwd"),
    ])
    try:
        destination = Path(tempfile.mkdtemp(prefix="vulpra-extract-"))
        try:
            benchmark_fixture.safe_extract(symlink_escape, destination, strip_components=1)
            raise SystemExit("FAIL: escaping symlink archive was extracted")
        except benchmark_fixture.FixtureError as error:
            require("link target" in str(error), f"symlink escape error is unclear: {error}")
    finally:
        symlink_escape.unlink(missing_ok=True)


def valid_attempt(identifier: int, benchmark_id: str, score: float = 17.4,
                  score_text: str | None = None) -> dict[str, object]:
    text = score_text if score_text is not None else f"{score:.2f}"
    return {
        "attempt": identifier,
        "benchmark": benchmark_id,
        "url": f"http://127.0.0.1:8765/runner/{benchmark_id}.html",
        "completed": True,
        "scoreText": text,
        "score": score,
        "scoreFrom": (
            f"Engine title: VulpraBenchmark {benchmark_id} score={text} monotonic_ns=12345"
        ),
        "elapsedMs": 120000,
        "appSurvived": True,
        "crashCount": 0,
        "launchStatus": 0,
        "launchAttempts": 1,
        "logShowStatus": 0,
        "logEvidenceSource": "merged-system+stream",
        "screenshotStatus": 0,
    }


def write_attempts(directory: Path, values: list[dict[str, object]]) -> None:
    directory.mkdir(parents=True)
    for value in values:
        (directory / f"attempt-{value['attempt']:02d}.json").write_text(
            json.dumps(value, indent=2) + "\n", encoding="utf-8"
        )


def run_summarizer(benchmark_id: str, directory: Path, count: int,
                   output: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run([
        "python3", str(SUMMARIZER), "--benchmark", benchmark_id,
        "--attempts", str(count), "--input", str(directory), "--output", str(output),
    ], text=True, capture_output=True, check=False)


def check_summarizer(manifest: dict[str, object]) -> None:
    benchmark_id = manifest["benchmarks"][0]["id"]
    with tempfile.TemporaryDirectory(prefix="vulpra-bench-summary-") as temporary:
        base = Path(temporary)
        good = base / "good"
        write_attempts(good, [valid_attempt(1, benchmark_id)])
        result = run_summarizer(benchmark_id, good, 1, base / "summary.json")
        require(result.returncode == 0, f"valid single attempt failed: {result.stderr}")
        summary = json.loads((base / "summary.json").read_text(encoding="utf-8"))
        require(summary["benchmarkPassed"] == 1 and summary["benchmarkAttempts"] == 1,
                "single-attempt summary is wrong")
        require(summary["scoreMedian"] == 17.4, "single-attempt scoreMedian is wrong")

        three = base / "three"
        write_attempts(three, [
            valid_attempt(1, benchmark_id, 10.0),
            valid_attempt(2, benchmark_id, 20.0),
            valid_attempt(3, benchmark_id, 30.0),
        ])
        result = run_summarizer(benchmark_id, three, 3, base / "three.json")
        require(result.returncode == 0, f"valid 3-attempt gate failed: {result.stderr}")
        summary = json.loads((base / "three.json").read_text(encoding="utf-8"))
        require(summary["scoreMin"] == 10.0 and summary["scoreMedian"] == 20.0
                and summary["scoreMax"] == 30.0,
                "3-attempt score stats are wrong")

        def expect_failure(name: str, values: list[dict[str, object]],
                           token: str, count: int | None = None) -> None:
            directory = base / name
            write_attempts(directory, values)
            result = run_summarizer(benchmark_id, directory,
                                    count or len(values), base / f"{name}.json")
            require(result.returncode != 0, f"invalid fixture passed: {name}")
            require(token in result.stderr, f"{name} did not report {token!r}: {result.stderr}")

        not_completed = copy.deepcopy([valid_attempt(1, benchmark_id)])
        not_completed[0]["completed"] = False
        expect_failure("not-completed", not_completed, "did not report a score")

        zero_score = copy.deepcopy([valid_attempt(1, benchmark_id)])
        zero_score[0]["score"] = 0.0
        expect_failure("zero-score", zero_score, "score must be positive")

        bad_text = copy.deepcopy([valid_attempt(1, benchmark_id)])
        bad_text[0]["scoreText"] = "Error"
        expect_failure("error-text", bad_text, "scoreText is not a plain number")

        wrong_benchmark = copy.deepcopy([valid_attempt(1, benchmark_id)])
        wrong_benchmark[0]["benchmark"] = "jetstream"
        expect_failure("wrong-benchmark", wrong_benchmark, "does not match --benchmark")

        no_evidence = copy.deepcopy([valid_attempt(1, benchmark_id)])
        no_evidence[0]["scoreFrom"] = "some other line"
        expect_failure("no-evidence", no_evidence, "is not an Engine title evidence line")

        crashed = copy.deepcopy([valid_attempt(1, benchmark_id)])
        crashed[0]["crashCount"] = 1
        expect_failure("crash", crashed, "contains a crash")

        died = copy.deepcopy([valid_attempt(1, benchmark_id)])
        died[0]["appSurvived"] = False
        expect_failure("died", died, "did not survive")

        launch_failed = copy.deepcopy([valid_attempt(1, benchmark_id)])
        launch_failed[0]["launchStatus"] = 1
        expect_failure("launch-failed", launch_failed, "launch did not succeed")

        gap = [valid_attempt(1, benchmark_id), valid_attempt(3, benchmark_id)]
        expect_failure("gap", gap, "identifiers must be exactly 1...3", count=3)

        extra = [valid_attempt(1, benchmark_id), valid_attempt(2, benchmark_id),
                 valid_attempt(3, benchmark_id)]
        expect_failure("extra", extra, "identifiers must be exactly 1...2", count=2)


def check_workflow_benchmark_defaults(manifest: dict[str, object]) -> None:
    """The workflow's benchmarks input default must match enabledByDefault ids."""
    workflow = WORKFLOW.read_text(encoding="utf-8")
    expected = ",".join(benchmark_fixture.enabled_by_default_ids(manifest))
    require("default: " + expected in workflow,
            f"benchmark-ci.yml benchmarks input default must be {expected!r}")
    require("validate-benchmark-selection.py --ids" in workflow,
            "benchmark-ci.yml validation step must call the shared selector validator")
    for benchmark_id in benchmark_fixture.enabled_by_default_ids(manifest):
        require(f"{benchmark_id}," in workflow or f",{benchmark_id}\n" in workflow
                or workflow.count(benchmark_id) >= 2,
                f"benchmark-ci.yml gate loop must reference {benchmark_id}")


def check_selection_validator() -> None:
    """The shared selection validator must refuse bad/JIT-backend selections."""
    spec = importlib.util.spec_from_file_location("vulpra_benchmark_validator", VALIDATOR)
    validator = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(validator)

    selected = validator.validate_selection("speedometer3,motionmark")
    require([entry["id"] for entry in selected] == ["speedometer3", "motionmark"],
            "validator must accept the default benchmark set")

    for ids, token in (
        ("jetstream", "JIT backend"),
        ("speedometer3,jetstream", "JIT backend"),
        ("", "no benchmark ids selected"),
        ("speedometer3,bogus", "unknown benchmark ids"),
    ):
        try:
            validator.validate_selection(ids)
        except validator.benchmark_fixture.FixtureError as error:
            require(token in str(error), f"validator rejection for {ids!r} lacks {token!r}: {error}")
        else:
            raise SystemExit(f"FAIL: validator accepted invalid selection {ids!r}")


def check_source_wiring() -> None:
    session = (ROOT / "Engine" / "VulpraEngineKit" / "Internal" / "Session"
               / "VulpraEngineSession.swift").read_text(encoding="utf-8")
    require('case "GeckoView:PageTitleChanged":' in session,
            "VulpraEngineSession missing PageTitleChanged case")
    require('"Engine title: \\(title, privacy: .public)' in session,
            "VulpraEngineSession must log the page title publicly")

    harness = HARNESS.read_text(encoding="utf-8")
    for token in (
        "benchmark_score_in_file", "Engine title: VulpraBenchmark",
        "VULPRA_SMOKE_URL", "timeoutSeconds", "merged-system+stream",
        "score_via=stream", "score_via=persisted-store",
    ):
        require(token in harness, f"benchmark harness missing {token!r}")

    summarizer = SUMMARIZER.read_text(encoding="utf-8")
    for token in ("ATTEMPT_KEYS", "scoreMedian", "Engine title: VulpraBenchmark",
                  "--benchmark", "--attempts", "--input", "--output"):
        require(token in summarizer, f"benchmark summarizer missing {token!r}")

    workflow = (ROOT / ".github" / "workflows" / "benchmark-ci.yml").read_text(encoding="utf-8")
    for token in ("run-simulator-benchmark.sh", "summarize-benchmark.py",
                  "benchmark-fixture.py fetch", "benchmark-fixture.py generate",
                  "iPad Pro 12.9-inch", "upload-artifact"):
        require(token in workflow, f"benchmark workflow missing {token!r}")


def check_runner_simulation(manifest: dict[str, object]) -> None:
    if shutil.which("node") is None:
        print("SKIP: node not available; runner JS simulation skipped")
        return
    with tempfile.TemporaryDirectory(prefix="vulpra-bench-node-") as temporary:
        base = Path(temporary)
        sources = base / "sources"
        make_synthetic_sources(sources, manifest)
        fixture = base / "fixture"
        result = run_generator([
            "generate", "--fixture-dir", str(fixture), "--benchmark-dir", str(sources),
        ], ROOT)
        require(result.returncode == 0, f"generate failed for node simulation: {result.stderr}")

        script = f'''
const {{ readFileSync }} = await import("node:fs");
const fixture = {json.dumps(str(fixture / "runner"))};

function makeDoc(frame, overrides = {{}}) {{
  const state = {{ title: "initial", startButtonDisabled: true, scoreText: "",
                   progressLabel: "", progressText: "",
                   progressValue: null, progressMax: null, ...overrides }};
  return {{
    state,
    title: state.title,
    getElementById(id) {{
      if (id === "bench") return frame;
      if (id === "start-button") return {{ disabled: state.startButtonDisabled }};
      return null;
    }},
    querySelector(sel) {{
      if (sel === "#start-button") return {{ disabled: state.startButtonDisabled }};
      if (sel === "#info-label") return state.progressLabel ? {{ textContent: state.progressLabel }} : null;
      if (sel === "#info-progress") return state.progressText ? {{ textContent: state.progressText }} : null;
      if (sel === "#progress-completed") {{
        if (state.progressValue == null || state.progressMax == null) return null;
        return {{ value: state.progressValue, max: state.progressMax }};
      }}
      if (sel === "#result-number" || sel === "#result-summary .score" || sel === "#results .score") {{
        return state.scoreText ? {{ textContent: state.scoreText }} : null;
      }}
      return null;
    }},
  }};
}}

function run(id, doc, win) {{
  const html = readFileSync(`${{fixture}}/${{id}}.html`, "utf8");
  const script = html.match(/<script>([\\s\\S]*?)<\\/script>/)[1];
  new Function("document", script)(doc);
}}

function scenario(id, steps, ms = 3600) {{
  return new Promise((resolve, reject) => {{
    const calls = {{ value: 0 }};
    const history = [];
    const win = {{ benchmarkController: {{ frameRateDetectionComplete: false, startBenchmark() {{ calls.value++; }} }} }};
    const frame = {{ contentWindow: win, contentDocument: null }};
    const doc = makeDoc(frame, {{}});
    frame.contentDocument = doc;
    run(id, doc, win);
    let t = 0;
    const timer = setInterval(() => {{
      t += 500;
      steps(t, doc.state, win);
      history.push({{ t, calls: calls.value, title: doc.title }});
      if (t >= ms) {{ clearInterval(timer); resolve({{ doc, calls, history }}); }}
    }}, 500);
    setTimeout(() => {{ clearInterval(timer); reject(new Error("timeout")); }}, ms + 2000);
  }});
}}

function assert(cond, msg) {{ if (!cond) throw new Error("ASSERT FAIL: " + msg); }}
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
await delay(100); // let the browser-shaped globals settle (no-op)

{{{{ // speedometer3 auto-start
  const {{ doc }} = await scenario("speedometer3", (t, s) => {{ if (t >= 1000) s.scoreText = "17.40"; }});
  assert(doc.title === "VulpraBenchmark speedometer3 score=17.40", `speedometer title: ${{doc.title}}`);
  console.log("speedometer3 OK");
}}}}

{{{{ // speedometer3 progress lines are published before the final score
  const {{ doc, history }} = await scenario("speedometer3", (t, s) => {{
    if (t >= 1000) {{
      s.progressLabel = "Running TodoMVC";
      s.progressText = "3/11";
      s.progressValue = 3;
      s.progressMax = 11;
    }}
    if (t >= 2000) {{
      s.progressLabel = "";
      s.progressText = "";
      s.progressValue = null;
      s.progressMax = null;
      s.scoreText = "17.40";
    }}
  }});
  const titles = history.map((h) => h.title);
  assert(titles.some((t) => t.startsWith("VulpraBenchmark speedometer3 progress=")
                     && t.includes("bar=3/11") && t.includes("elapsed=")),
         `progress title missing: ${{titles.join(" | ")}}`);
  assert(doc.title === "VulpraBenchmark speedometer3 score=17.40", `final score title: ${{doc.title}}`);
  console.log("speedometer3-progress OK");
}}}}

{{{{ // motionmark controller start: waits for frameRateDetectionComplete, not the portrait-disabled button
  const {{ doc, calls, history }} = await scenario("motionmark", (t, s, win) => {{
    if (t >= 1000) win.benchmarkController.frameRateDetectionComplete = true;
    if (t >= 2000) s.scoreText = "123.45 @ 60fps";
  }});
  assert(history.length > 0 && history[0].calls === 0,
         `motionmark started before frame-rate detection: ${{history.length ? history[0].calls : "no ticks"}}`);
  assert(calls.value === 1, `motionmark start calls: ${{calls.value}}`);
  assert(doc.title === "VulpraBenchmark motionmark score=123.45_@_60fps", `motionmark title: ${{doc.title}}`);
  console.log("motionmark OK");
}}}}

{{{{ // jetstream auto-start
  const {{ doc }} = await scenario("jetstream", (t, s) => {{ if (t >= 1500) s.scoreText = "245.32"; }});
  assert(doc.title === "VulpraBenchmark jetstream score=245.32", `jetstream title: ${{doc.title}}`);
  console.log("jetstream OK");
}}}}

{{{{ // error text must not become a score
  const {{ doc }} = await scenario("speedometer3", (t, s) => {{ if (t >= 1000) s.scoreText = "Error"; }});
  assert(doc.title === "initial", `error guard failed: ${{doc.title}}`);
  console.log("error-guard OK");
}}}}
console.log("RUNNER JS SIMULATION PASSED");
process.exit(0);
'''
        node_file = base / "simulate.mjs"
        node_file.write_text(script, encoding="utf-8")
        result = subprocess.run(
            ["node", str(node_file)], text=True, capture_output=True, check=False, timeout=120
        )
        require(result.returncode == 0,
                f"runner JS simulation failed: {result.stdout}\n{result.stderr}")
        require("RUNNER JS SIMULATION PASSED" in result.stdout,
                f"runner JS simulation did not complete: {result.stdout}")


def main() -> None:
    manifest = load_manifest()
    check_manifest_entries(manifest)
    check_generate(manifest)
    check_safe_extract()
    check_summarizer(manifest)
    check_workflow_benchmark_defaults(manifest)
    check_selection_validator()
    check_source_wiring()
    check_runner_simulation(manifest)
    print("PASS: benchmark manifest, fixture generator, secure tar, summarizer, "
          "selection validator, workflow defaults, title evidence, harness "
          "wiring, and runner JS contracts")
    return None


if __name__ == "__main__":
    raise SystemExit(main())
