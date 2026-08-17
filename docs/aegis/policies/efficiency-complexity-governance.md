# Vulpra Efficiency and Complexity Governance

Date: `2026-07-21`
Status: `active`

## Scope

Efficiency is a Product and Architecture non-negotiable. This policy governs
all Git-tracked, Vulpra-maintained code, tests, tools, documentation, resources,
configuration, workflows, and future authored roots. Imported `Vendor/`, raw
`Patches/`, and generated/build outputs are measured separately and cannot hide
Vulpra-authored growth.

Pressure signals include a maintained file at or above 800 lines, a cohesive
touched block around 80 lines or more, mixed reasons to change, generic
manager/controller growth, duplicate owners/fallbacks/adapters, dependency
sprawl, and process-artifact sprawl. These are review triggers, not arbitrary
deletion instructions. Preserve required functionality and split by coherent
owner before adding to an over-budget artifact.

## Maintained-File Pressure Report

Run from the repository root. This reports pressure; it does not fail merely
because a file crosses 800 lines. It scans every Git-tracked file, including
future authored roots, while excluding only separately governed imported or
output paths. `Tools/Build/` remains in scope.

```bash
python3 - <<'PY'
from pathlib import Path
import subprocess

tracked = subprocess.check_output(["git", "ls-files", "-z"]).split(b"\0")
excluded_prefixes = (
    "Vendor/", "Patches/", ".git/", "dist/", ".build/", "build/",
    "out/", "DerivedData/",
)
for raw in sorted(p for p in tracked if p):
    path = Path(raw.decode("utf-8", "surrogateescape"))
    normalized = path.as_posix()
    if any(normalized == prefix[:-1] or normalized.startswith(prefix)
           for prefix in excluded_prefixes):
        continue
    try:
        lines = sum(1 for _ in path.open("r", encoding="utf-8", errors="ignore"))
    except OSError:
        continue
    if lines >= 800:
        print(f"{lines:6d} {path}")
PY
```

If a new output directory appears, add only its normalized repository-root path
prefix after proving it is generated and recording owner review. Nested paths
such as `Sources/Generated/` remain scanned unless that exact prefix is added to
the generated-output registry with evidence. Never add component-name filters
that could silently exclude a future authored root.

## Dependency Inventory

No third-party dependency may be added without documenting its requirement,
binary/runtime cost, security/update owner, and native/platform alternative.
Run this tracked-file inventory and review the commit diff for new unknown
manifest or lock formats:

```bash
python3 - <<'PY'
from pathlib import Path
import subprocess

tracked = [
    Path(p.decode("utf-8", "surrogateescape"))
    for p in subprocess.check_output(["git", "ls-files", "-z"]).split(b"\0")
    if p
]
known_names = {
    "Package.swift", "Package.resolved", "Podfile", "Podfile.lock",
    "Cartfile", "Cartfile.resolved", "package.json", "package-lock.json",
    "npm-shrinkwrap.json", "yarn.lock", "pnpm-lock.yaml", "bun.lock",
    "bun.lockb", "Cargo.toml", "Cargo.lock", "Gemfile", "Gemfile.lock",
    "gems.rb", "gems.locked", "pyproject.toml", "poetry.lock", "Pipfile",
    "Pipfile.lock", "requirements.txt", "go.mod", "go.sum", "build.gradle",
    "build.gradle.kts", "settings.gradle", "settings.gradle.kts",
    "gradle.lockfile", "pom.xml", "composer.json", "composer.lock",
    "packages.config", "Directory.Packages.props", "project.assets.json",
    "CMakeLists.txt", "vcpkg.json", "conanfile.txt", "conanfile.py",
}
known_suffixes = (".podspec", ".gemspec", ".csproj", ".fsproj", ".vbproj")
for path in sorted(tracked):
    name = path.name
    lower = name.lower()
    if (
        name in known_names
        or name.startswith("requirements-") and name.endswith(".txt")
        or name.endswith(known_suffixes)
        or lower.endswith((".lock", ".lockfile"))
        or "dependencies" in lower
        or "dependency" in lower
        or "manifest" in lower
    ):
        print(path)
PY
git diff --name-status HEAD^ -- | grep -Ei \
  '(^|/)([^/]*(manifest|dependenc|lock)[^/]*|package[^/]*\.json)$' || true
```

The last diff review is mandatory: classify new unknown formats rather than
silently assuming they are not dependency owners.

## Reproducible Performance Evidence

Each measurement record must include:

- exact Git commit and artifact checksum/identifier;
- Release-equivalent build configuration;
- device model and chip, OS version, installation mode, and JIT mode;
- thermal state, battery/charging state, measurement tool and tool version;
- deterministic workload, data set, network conditions, and warm/cold cache
  state;
- baseline artifact/reference and delta versus that verified baseline.

Use at least five samples per measured case and report median and p95. Record
raw samples or a machine-readable attachment so the summary is reproducible.

Startup has two separate endpoints: chrome interactive, and first Gecko session
ready. Cold and warm runs must state cache/process reset conditions.

Memory evidence states the workload and measurement source, then reports
steady-state memory and per-tab growth for a deterministic tab/content set.

Frame evidence reports p95 frame time at both supported refresh classes:
16.67 ms at 60 Hz and 8.33 ms at 120 Hz. A hitch is a frame exceeding 1.5 times
the applicable frame budget; report hitch count/rate and workload.

## Phase Gates

- Phase 0 may retain performance metrics as `needs-verification`.
- `vulpra-runtime-shell` cannot complete without Vulpra client size/resource and
  both startup-endpoint evidence.
- `vulpra-browser-ui` cannot complete without 60/120 Hz frame evidence.
- `vulpra-reliability-and-release` cannot complete without physical-device
  evidence on iOS 15.8 and iOS 16.7.
- Missing required evidence is `needs-verification`, never pass by assumption.

## Complexity Closure

Use after every Task 3-8 slice/review and every follow-up implementation slice:

```text
Complexity Closure:
- Budget status: within-budget | exceeded-and-governed | exceeded-unresolved
- Maintained files >=800 lines:
- Cohesive touched blocks ~80+ lines:
- Owner map / mixed-reason review:
- Dependencies added or removed:
- Vulpra binary/resource delta:
- IPA and Gecko/vendor delta (separate):
- Performance protocol record / raw evidence:
- Chrome-interactive startup median/p95:
- First-Gecko-session-ready startup median/p95:
- Steady-state + per-tab memory median/p95:
- Frame p95 and >1.5x-budget hitch rate at 60/120 Hz:
- Regression versus verified baseline artifact:
- Governed now:
- Deferred follow-up:
- Independent owner review:
- Completion impact: complete | needs-follow-up | not-complete
```

`exceeded-unresolved` blocks completion. `exceeded-and-governed` requires a
named owner, objective containment/retirement controls, and independent review.
