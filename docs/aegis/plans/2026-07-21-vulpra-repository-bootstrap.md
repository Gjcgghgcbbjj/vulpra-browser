# Vulpra Repository Bootstrap and Substrate Extraction Implementation Plan

## Goal

Create `/root/vulpra-browser` as a fresh, standalone Git repository; import only
the audited Gecko/iOS substrate from Reynard source commit
`ef14c2997ae7dfdb44155240ec64fea3140ba9e1`; rename active runtime/build identity
to Vulpra; and establish portable gates that prove no legacy client or old data
compatibility path entered the new repository.

This plan is **Phase 0** of the approved full Vulpra rewrite. It deliberately
stops before creating the Vulpra Xcode application target. The next plan starts
only after this substrate boundary is verified.

## Architecture

The new repository owns its Git history, documentation, import manifest, and
build tooling. Firefox and idevice remain upstream submodules. Gecko patches,
GeckoView, Helper, low-level JIT code, and required native utilities are imported
from one pinned source commit. No Reynard client, persistence, UI, app entry
point, or product resource is copied.

```text
Vendor/firefox + Patches
          ↓
Extensions/GeckoView + Extensions/Helper
          ↓
Modules/VulpraRuntime/JIT + Native
          ↓
future Vulpra runtime/app plans
```

## Tech Stack

- Git and Git submodules
- Bash/Zsh/Python 3 bootstrap verification
- Swift/Objective-C/Objective-C++/C substrate sources
- Mozilla Gecko for iOS arm64
- Rust `idevice` FFI
- UIKit deployment target: iOS 15.0+
- GitHub Actions on macOS for later Gecko/Xcode gates

## Baseline/Authority Refs

Unless explicitly identified as target-repository paths, relative evidence
paths in this plan refer to the source repository at pinned commit `ef14c29`.

- `docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md`
- `docs/aegis/baseline/2026-07-19-initial-baseline.md`
- `docs/aegis/baseline/2026-07-20-frontend-redesign-baseline.md`
- `docs/aegis/specs/2026-07-20-gecko-artifact-pipeline-brief.md`
- `.gitmodules`
- `engine/release.txt`
- `browser/GeckoView/`
- `browser/Helper/`
- `browser/Reynard/JIT/`
- `browser/Reynard/Shared/Utils.h`
- `browser/Reynard/Shared/Utils.m`
- `browser/Scripts/AddGecko.sh`
- `patches/`
- `support/idevice/`
- `tools/development/`

## Compatibility Boundary

- Target iOS version is `15.0`; device acceptance later covers iOS 15.8 and
  iOS 16.7.
- Gecko remains the only normal renderer.
- The source repository is not modified by bootstrap execution.
- No old bundle ID, app group, URL scheme, database, preferences domain, or
  backup is read.
- No `browser/Reynard/Client` source, client test, product resource, old app
  entry point, or Xcode project is imported.
- Preserved copyright/provenance text and manifest-listed low-level patch names
  may contain `Reynard`; active Vulpra contracts may not.
- Remote creation and visibility are outside this plan. The plan produces a
  complete local repository ready to push.

## Verification

Run from `/root/vulpra-browser`:

```bash
./Tests/Bootstrap/test-repository-shape.sh
./Tests/Bootstrap/test-repository-shape-nested-parent.sh
./Tests/Bootstrap/test-import-boundary.sh
./Tests/Bootstrap/test-active-identity.sh
./Tools/Gecko/test-gecko-artifact.sh
find Tools Tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
git diff --check
git status --short
```

Expected final result:

```text
Repository shape checks passed.
Nested parent repository regression check passed.
Import boundary checks passed.
Active identity checks passed.
Gecko artifact contract tests passed.
```

`git status --short` must be empty after the final task commit.

## Plan Basis

- **Fact:** the current application deployment target is 16.0, but Gecko and
  idevice build scripts already target iOS 13.0.
- **Fact:** the candidate substrate contains active Reynard identifiers in
  Helper, Gecko feature events, JIT queues/errors, artifact names, and paths.
- **Fact:** `JITController.swift` and `Interface/JITFailure.swift` mix runtime
  mechanics with UIKit product presentation and are excluded from Phase 0.
- **Assumption:** source commit `ef14c29` remains locally reachable during
  execution. The import script verifies it before copying anything.
- **Unknown:** Xcode link closure for the new target. That is intentionally
  deferred to the runtime-shell plan after the imported source boundary is
  stable.

## BaselineUsageDraft

- **Required baseline refs:** approved Vulpra design, current Gecko/JIT/Helper
  ownership, Gecko artifact contract, and source commit.
- **Delivered context refs:** user approved a fresh repository, complete client
  rewrite, no old-data migration, Vulpra branding, and iOS 15+ support.
- **Acknowledged before plan refs:** all refs listed under
  `Baseline/Authority Refs`.
- **Cited in plan refs:** import allowlist, active-identity map, and verification
  tasks below.
- **Missing refs:** macOS/Xcode link evidence and device evidence, neither of
  which is required to complete Phase 0.
- **Decision:** `continue`.

## Requirement Ready Check

- **Requirement source refs:** approved Vulpra design and the iOS 15 scope
  amendment in commit `db3b8e0`.
- **Goals and scope refs:** Goal, Compatibility Boundary, and Tasks 1-8.
- **User/scenario refs:** a clean Vulpra codebase that later produces a
  TrollStore-first full browser on iOS 15+.
- **Requirement item refs:** approved design sections 8, 9, 12, 13, 14.1, and
  15.1-5.
- **Acceptance/verification refs:** Verification plus Task 8.
- **Open blocker questions:** none for a local repository bootstrap.
- **Decision:** `ready`.

## Architecture Integrity Lens

- **Invariant:** imported substrate owns engine/process/JIT mechanics only;
  product behavior never enters through convenience copying.
- **Canonical owner/contract:** the allowlist and generated import manifest are
  the source-of-truth for imported files.
- **Responsibility overlap:** old JIT UI/controller and all client/store owners
  are excluded; no compatibility adapter is created.
- **Higher-level simplification:** import directly from a pinned Git tree rather
  than copying the current working tree or retaining the source as a submodule.
- **Retirement/falsifier:** a required build dependency on an excluded client
  file stops execution and returns to architecture review.
- **Verdict:** `proceed`.

## Plan Pressure Test

- **Owner/contract/retirement:** explicit import allowlist; delete-first by
  non-import; no legacy runtime owner.
- **Architecture integrity/higher-level path:** fresh repository is the cleanest
  ownership boundary.
- **Verification scope:** portable import, identity, manifest, shell, and Gecko
  artifact checks; Xcode/device gates are intentionally deferred.
- **Task executability:** every task has exact source/target paths and commands.
- **Pressure result:** `proceed`.

## Complexity Budget

- **Artifact class:** repository extraction and build-substrate migration.
- **Target files/artifacts:** repository metadata, import script, manifest,
  submodules, patches, Gecko tooling, GeckoView, Helper, and low-level JIT.
- **Current pressure:** 355 candidate substrate files plus implicit path/name
  dependencies.
- **Projected post-change pressure:** bounded by a generated manifest and three
  automated boundary scans.
- **Budget result:** `within-budget` for Phase 0; full client work remains split.
- **Planned governance:** one responsibility group and one commit per task.

## Plan-Time Complexity Check

- **Target files:** new repository only; no edits to old client source.
- **Existing size/shape signals:** Gecko patches are numerous but mechanically
  imported; GeckoView and Helper are cohesive runtime groups; JIT requires a
  file-level split.
- **Owner fit:** good after excluding UIKit JIT presentation.
- **Add-in-place risk:** copying the source Xcode project or entire `browser/`
  directory would reintroduce product ownership.
- **Better file boundary:** allowlisted groups under `Vendor`, `Patches`,
  `Extensions`, `Modules`, and `Tools`.
- **Recommendation:** `split task` as below.

## File Map

### Create in `/root/vulpra-browser`

- `.gitignore`
- `.gitmodules`
- `LICENSE`
- `LICENSE.firefox`
- `NOTICE.md`
- `README.md`
- `docs/aegis/README.md`
- `docs/aegis/INDEX.md`
- `docs/aegis/BASELINE-GOVERNANCE.md`
- `docs/aegis/baseline/2026-07-21-initial-baseline.md`
- `docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md`
- `docs/aegis/plans/2026-07-21-vulpra-repository-bootstrap.md`
- `Tools/Bootstrap/import-substrate.sh`
- `Tools/Bootstrap/import-allowlist.tsv`
- `Tools/Bootstrap/generate-import-manifest.py`
- `Tools/Bootstrap/active-identity-allowlist.txt`
- `Tools/Gecko/*.sh`
- `Tools/Build/AddGecko.sh`
- `Tests/Bootstrap/test-repository-shape.sh`
- `Tests/Bootstrap/test-repository-shape-nested-parent.sh`
- `Tests/Bootstrap/test-import-boundary.sh`
- `Tests/Bootstrap/test-active-identity.sh`
- `docs/provenance/import-manifest.tsv`

### Import and relocate

- `engine/release.txt` -> `Vendor/firefox-release.txt`
- `patches/` -> `Patches/`
- `browser/GeckoView/` -> `Extensions/GeckoView/`
- `browser/Helper/` -> `Extensions/Helper/`
- `browser/Reynard/JIT/JITEnabler.*` -> `Modules/VulpraRuntime/JIT/`
- `browser/Reynard/JIT/JITErrors.*` -> `Modules/VulpraRuntime/JIT/`
- `browser/Reynard/JIT/RPPairing/` ->
  `Modules/VulpraRuntime/JIT/RPPairing/`, excluding generated
  `libidevice_ffi.a`
- `browser/Reynard/JIT/Unsandboxed/` ->
  `Modules/VulpraRuntime/JIT/Unsandboxed/`
- `browser/Reynard/Shared/Utils.h` and `Utils.m` ->
  `Modules/VulpraRuntime/Native/`
- `browser/Scripts/AddGecko.sh` -> `Tools/Build/AddGecko.sh`
- `tools/development/*.sh` -> `Tools/Gecko/*.sh`

### Never import

- `browser/Reynard/Client/`
- `browser/Reynard/BrowserCore/`
- `browser/Reynard/StabilityCore/`
- `browser/Reynard/JIT/JITController.swift`
- `browser/Reynard/JIT/Interface/`
- `browser/Reynard/AppDelegate.swift`
- `browser/Reynard/SceneDelegate.swift`
- `browser/Reynard/Resources/`
- `browser/Reynard.xcodeproj/`
- `browser/Configuration/Reynard.xcconfig`
- `Tests/Reynard*`

## Task 1: Initialize the fresh local repository and authority documents

**Files:** create `.gitignore`, `README.md`, `NOTICE.md`, licenses,
`Tests/Bootstrap/test-repository-shape.sh`,
`Tests/Bootstrap/test-repository-shape-nested-parent.sh`, and `docs/aegis/**`
listed in the file map.

**Why:** establish independent history and authority before any inherited source
enters the repository.

**Impact/Compatibility:** no source repository mutation; no remote creation.

**Verification:** repository shape test and Git history count.

- [ ] **Write the failing test.** Create
  `Tests/Bootstrap/test-repository-shape.sh` with:

  ```bash
  #!/bin/sh
  set -eu
  root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
  required="README.md NOTICE.md LICENSE LICENSE.firefox docs/aegis/README.md docs/aegis/INDEX.md docs/aegis/BASELINE-GOVERNANCE.md docs/aegis/baseline/2026-07-21-initial-baseline.md docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md docs/aegis/plans/2026-07-21-vulpra-repository-bootstrap.md"
  for path in $required; do
      [ -f "$root/$path" ] || { echo "missing required file: $path" >&2; exit 1; }
  done

  git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || {
      echo "repository root is not a Git worktree: $root" >&2
      exit 1
  }
  [ "$git_root" = "$root" ] || {
      echo "repository root is not the Git toplevel: $root (found $git_root)" >&2
      exit 1
  }

  [ "$(git -C "$root" rev-list --count HEAD 2>/dev/null || echo 0)" -ge 1 ] || {
      echo "repository has no initial commit" >&2
      exit 1
  }

  while IFS='|' read -r _date _kind indexed_path _title _rest; do
      indexed_path=$(printf '%s\n' "$indexed_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      case "$indexed_path" in
          docs/*)
              [ -f "$root/$indexed_path" ] || {
                  echo "indexed workspace file does not exist: $indexed_path" >&2
                  exit 1
              }
              ;;
      esac
  done < "$root/docs/aegis/INDEX.md"

  echo "Repository shape checks passed."
  ```

- [ ] **Add the nested-parent regression fixture.** Create
  `Tests/Bootstrap/test-repository-shape-nested-parent.sh` as a POSIX `sh`
  test that creates a temporary directory below `/root/vulpra-browser`, copies
  the shape test and its required fixture files without creating `.git`, and
  requires failure containing `repository root is not the Git toplevel:`.

- [ ] **Verify RED.** Run:

  ```bash
  fixture="$(mktemp -d)"
  cleanup() {
      find "$fixture" -type f -exec rm -f {} \;
      find "$fixture" -depth -type d -exec rmdir {} \;
  }
  trap cleanup EXIT HUP INT TERM
  mkdir -p "$fixture/Tests/Bootstrap"
  cp /root/vulpra-browser/Tests/Bootstrap/test-repository-shape.sh \
      "$fixture/Tests/Bootstrap/"
  sh "$fixture/Tests/Bootstrap/test-repository-shape.sh"
  ```

  Expected: non-zero exit with `missing required file: README.md`.

- [ ] **Implement the minimal repository skeleton.** Run:

  ```bash
  cd /root/vulpra-browser
  git init -b main
  mkdir -p docs/aegis/{baseline,plans,specs,adr,work} docs/provenance
  cp /root/reynard-browser/docs/aegis/BASELINE-GOVERNANCE.md docs/aegis/BASELINE-GOVERNANCE.md
  cp /root/reynard-browser/docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md docs/aegis/specs/
  cp /root/reynard-browser/docs/aegis/plans/2026-07-21-vulpra-repository-bootstrap.md docs/aegis/plans/
  cat > README.md <<'EOF'
  # Vulpra Browser

  Vulpra Browser is planned as a Gecko-based browser client for iOS 15 and later.
  This repository is currently in its bootstrap state: it contains authority,
  licensing, and verification records, but no imported Gecko/iOS substrate or
  browser implementation.

  A future audited substrate import is planned from
  `https://github.com/Gjcgghgcbbjj/reynard-browser` at commit
  `ef14c2997ae7dfdb44155240ec64fea3140ba9e1`.
  EOF
  cat > NOTICE.md <<'EOF'
  # Notices and Provenance

  This bootstrap repository currently contains Vulpra-authored documentation and
  verification material. No Gecko/iOS substrate or inherited patch set has been
  imported yet.

  A future audited substrate import is planned from
  https://github.com/Gjcgghgcbbjj/reynard-browser at commit
  ef14c2997ae7dfdb44155240ec64fea3140ba9e1.

  Unless otherwise noted, all Vulpra-authored repository material, including
  documentation, verification scripts, and future application code, is licensed
  under SPDX `GPL-3.0-only`. Future imported Gecko patch material will remain
  under SPDX `MPL-2.0` according to its file notices and the documented license
  boundary.
  EOF
  cat > .gitignore <<'EOF'
  .DS_Store
  .build/
  DerivedData/
  dist/
  Vendor/firefox/obj-*/
  Vendor/idevice/target/
  Modules/VulpraRuntime/JIT/RPPairing/libidevice_ffi.a
  EOF
  cat > docs/aegis/README.md <<'EOF'
  # Vulpra Aegis Workspace

  This directory records Vulpra requirements, baselines, plans, ADRs, and work evidence.
  EOF
  cat > docs/aegis/INDEX.md <<'EOF'
  # Aegis Workspace Index

  | Date | Kind | Path | Title |
  | --- | --- | --- | --- |
  | 2026-07-21 | baseline | docs/aegis/baseline/2026-07-21-initial-baseline.md | Vulpra Initial Baseline |
  | 2026-07-21 | spec | docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md | Vulpra Core-Substrate Repository Design |
  | 2026-07-21 | plan | docs/aegis/plans/2026-07-21-vulpra-repository-bootstrap.md | Vulpra Repository Bootstrap and Substrate Extraction Implementation Plan |
  EOF
  cat > docs/aegis/baseline/2026-07-21-initial-baseline.md <<'EOF'
  # Vulpra Initial Baseline

  Date: `2026-07-21`
  Status: `empty-repository-before-substrate-import`

  ## Product / Requirement Baseline
  Vulpra is a new Gecko browser client for iOS 15+ with no Reynard user-data compatibility.

  ## Architecture / Runtime Boundary Baseline
  Only audited Gecko, GeckoView, Helper, low-level JIT, idevice, patch, and build substrate may be imported.

  ## Compatibility Boundary
  No old client, UI, persistence, brand resource, app entry point, or Xcode project enters this repository.
  EOF
  chmod +x Tests/Bootstrap/test-repository-shape.sh \
      Tests/Bootstrap/test-repository-shape-nested-parent.sh
  git add .
  git commit -m "chore: initialize Vulpra repository"
  ```

- [ ] **Verify GREEN.** Run:

  ```bash
  sh ./Tests/Bootstrap/test-repository-shape.sh
  dash ./Tests/Bootstrap/test-repository-shape.sh
  ./Tests/Bootstrap/test-repository-shape-nested-parent.sh
  python /root/.codex/aegis/scripts/aegis-workspace.py check --root /root/vulpra-browser
  git log --oneline --max-count=1
  ```

  Expected: all checks pass and the log shows
  `chore: initialize Vulpra repository`.

- [ ] **Commit.** The implementation step already creates the atomic initial
  commit. Confirm `git status --short` is empty.

## Task 2: Add a deterministic allowlisted importer and manifest generator

**Files:** create `Tools/Bootstrap/import-allowlist.tsv`,
`Tools/Bootstrap/import-substrate.sh`,
`Tools/Bootstrap/generate-import-manifest.py`, and
`Tests/Bootstrap/test-import-boundary.sh`.

**Why:** make imported ownership reviewable and reproducible from one Git tree.

**Impact/Compatibility:** imports tracked blobs only; working-tree changes in
the source repository cannot leak into Vulpra.

**Verification:** fixture import rejects non-allowlisted client files and records
source/target hashes.

- [ ] **Write the failing test.** Create
  `Tests/Bootstrap/test-import-boundary.sh` that constructs a temporary Git
  repository containing `allowed/file.txt` and `browser/Reynard/Client/leak.swift`,
  runs the importer with an allowlist containing only `allowed/file.txt`, and
  asserts that the allowed file and manifest exist while `leak.swift` does not.

- [ ] **Verify RED.** Run:

  ```bash
  ./Tests/Bootstrap/test-import-boundary.sh
  ```

  Expected: non-zero exit because `Tools/Bootstrap/import-substrate.sh` does not
  exist.

- [ ] **Implement the minimal importer.** Use a TSV format of
  `source-path<TAB>target-path`. The importer must verify the source commit with
  `git cat-file -e "$SOURCE_SHA^{commit}"`, export each allowlisted blob/tree
  through `git archive "$SOURCE_SHA" -- "$source_path"`, relocate it into the
  exact target path, reject target paths containing `..`, and finally run:

  ```bash
  python3 Tools/Bootstrap/generate-import-manifest.py \
      "$SOURCE_REPO" "$SOURCE_SHA" \
      Tools/Bootstrap/import-allowlist.tsv \
      docs/provenance/import-manifest.tsv
  ```

  The manifest columns must be:

  ```text
  source_commit source_path target_path sha256
  ```

- [ ] **Verify GREEN.** Run:

  ```bash
  ./Tests/Bootstrap/test-import-boundary.sh
  python3 -m py_compile Tools/Bootstrap/generate-import-manifest.py
  ```

  Expected: `Import boundary checks passed.` and no Python error.

- [ ] **Commit.** Run:

  ```bash
  git add Tools/Bootstrap Tests/Bootstrap docs/provenance
  git commit -m "build: add audited substrate importer"
  ```

## Task 3: Import Firefox metadata, patches, Gecko tooling, and submodule pins

**Files:** populate `Vendor/firefox-release.txt`, `Patches/`, `Tools/Gecko/`,
`Tools/Build/AddGecko.sh`, `.gitmodules`, `Vendor/firefox`, and `Vendor/idevice`.

**Why:** establish the engine/build substrate before importing application-side
runtime code.

**Impact/Compatibility:** preserves upstream submodule commits recorded by the
pinned source tree; changes repository paths and active artifact identity.

**Verification:** artifact contract fixture, patch inventory, and submodule SHA
checks.

- [ ] **Write the failing test.** Extend `test-import-boundary.sh` to require:
  `Vendor/firefox-release.txt`, at least one `Patches/**/*.patch`, every imported
  `Tools/Gecko/*.sh`, and manifest coverage for each. Add assertions that
  `.gitmodules` contains `Vendor/firefox` and `Vendor/idevice`.

- [ ] **Verify RED.** Run `./Tests/Bootstrap/test-import-boundary.sh` and expect
  `missing imported path: Vendor/firefox-release.txt`.

- [ ] **Implement the import and path port.** Add these mappings to the
  allowlist:

  ```text
  engine/release.txt	Vendor/firefox-release.txt
  patches	Patches
  tools/development	Tools/Gecko
  browser/Scripts/AddGecko.sh	Tools/Build/AddGecko.sh
  ```

  Run the importer with source commit `ef14c29`. Add the two submodules using
  the upstream URLs, then checkout the exact gitlink SHAs returned by:

  ```bash
  git -C /root/reynard-browser ls-tree ef14c29 engine/firefox support/idevice
  ```

  Rewrite tooling paths consistently:

  ```text
  engine/release.txt                    -> Vendor/firefox-release.txt
  engine/firefox                        -> Vendor/firefox
  support/idevice                       -> Vendor/idevice
  patches                               -> Patches
  tools/development                     -> Tools/Gecko
  browser/Reynard/JIT/RPPairing         -> Modules/VulpraRuntime/JIT/RPPairing
  REYNARD_ROOT_DIR                      -> VULPRA_ROOT_DIR
  reynard-gecko-ios-arm64               -> vulpra-gecko-ios-arm64
  ```

  Update the artifact test fixture to use the new paths and unsafe member name
  `../vulpra-artifact-escape`.

- [ ] **Verify GREEN.** Run:

  ```bash
  ./Tools/Gecko/test-gecko-artifact.sh
  find Tools -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
  git submodule status -- Vendor/firefox Vendor/idevice
  find Patches -type f -name '*.patch' -print -quit | grep -q .
  ```

  Expected: artifact test passes; both submodules show pinned commits; patch
  search succeeds.

- [ ] **Commit.** Run:

  ```bash
  git add .gitmodules Vendor Patches Tools docs/provenance/import-manifest.tsv
  git commit -m "build: import Gecko substrate and tooling"
  ```

## Task 4: Import GeckoView and Helper while renaming active runtime contracts

**Files:** create `Extensions/GeckoView/**`, `Extensions/Helper/**`, and update
the import manifest and active-identity test.

**Why:** retain the process/session bridge without retaining the old browser
client or product identity.

**Impact/Compatibility:** changes active event/XPC/principal-class names. Matching
patch strings must change in the same commit.

**Verification:** no forbidden active identity remains; all imported files are
manifested; Swift/Objective-C source parses at the lexical level.

- [ ] **Write the failing test.** Create
  `Tests/Bootstrap/test-active-identity.sh` with forbidden patterns:

  ```text
  com.minh-ton
  ReynardXPCListenerEndpoint
  ReynardHelperMain
  Reynard:Features
  reynard://
  installId.*reynard-
  ```

  Scan `Extensions Modules Tools .github` when those paths exist. The test must
  not scan `NOTICE.md`, provenance files, copyright comments, or the explicit
  low-level-symbol allowlist.

- [ ] **Verify RED.** Import `browser/GeckoView` and `browser/Helper` without
  edits, run `./Tests/Bootstrap/test-active-identity.sh`, and expect it to report
  `ReynardXPCListenerEndpoint`.

- [ ] **Implement the minimal identity port.** Apply this exact active mapping:

  ```text
  ReynardXPCListenerEndpoint -> VulpraXPCListenerEndpoint
  ReynardHelperMain          -> VulpraHelperMain
  Reynard:Features:          -> Vulpra:Features:
  reynard-<install counter>  -> vulpra-<install counter>
  ```

  Update `Extensions/Helper/Info.plist`, `Helper.swift`, and the matching
  `Patches/ipc/glue/NSExtensionUtils.mm.patch` key together. Keep file-level
  provenance comments intact.

- [ ] **Verify GREEN.** Run:

  ```bash
  ./Tests/Bootstrap/test-active-identity.sh
  ./Tests/Bootstrap/test-import-boundary.sh
  plutil -lint Extensions/GeckoView/Info.plist Extensions/Helper/Info.plist 2>/dev/null || true
  ```

  Expected: both shell tests pass. `plutil` is authoritative on macOS and may be
  unavailable on Linux.

- [ ] **Commit.** Run:

  ```bash
  git add Extensions Patches Tools/Bootstrap docs/provenance Tests/Bootstrap
  git commit -m "feat: import Vulpra Gecko process bridge"
  ```

## Task 5: Import only low-level JIT and native substrate

**Files:** create `Modules/VulpraRuntime/JIT/**` and
`Modules/VulpraRuntime/Native/Utils.{h,m}`.

**Why:** retain JIT attachment mechanics without importing UIKit failure UI or
the old product-level JIT controller.

**Impact/Compatibility:** JIT presentation and orchestration remain absent until
the runtime-shell plan; low-level error domains and queue/service labels become
Vulpra-owned.

**Verification:** excluded JIT files are absent; native imports resolve within
the imported tree; active identity scan passes.

- [ ] **Write the failing test.** Extend `test-import-boundary.sh` to require the
  low-level JIT paths and to fail if either
  `Modules/VulpraRuntime/JIT/JITController.swift` or
  `Modules/VulpraRuntime/JIT/Interface/JITFailure.swift` exists.

- [ ] **Verify RED.** Run the boundary test and expect a missing
  `Modules/VulpraRuntime/JIT/JITEnabler.m` failure.

- [ ] **Implement the minimal import.** Add exact allowlist mappings for
  `JITEnabler.h`, `JITEnabler.m`, `JITErrors.h`, `JITErrors.m`, `RPPairing`,
  `Unsandboxed`, and `Shared/Utils.{h,m}`. Remove generated
  `libidevice_ffi.a` if present. Apply active replacements:

  ```text
  Reynard.JIT                         -> Vulpra.JIT
  com.minh-ton.Reynard.JITEnabler    -> com.vulpra.browser.jit.enabler
  com.minh-ton.Reynard.JITSupport    -> com.vulpra.browser.jit.support
  com.minh-ton.Reynard.DDIManager    -> com.vulpra.browser.jit.ddi
  ReynardDebug                       -> VulpraDebug
  tunnel display name Reynard        -> Vulpra
  me-minh-ton.jit.endpoint-monitor-failed
                                      -> com.vulpra.browser.jit.endpoint-monitor-failed
  ```

  Do not import or recreate a UI fallback.

- [ ] **Verify GREEN.** Run:

  ```bash
  ./Tests/Bootstrap/test-import-boundary.sh
  ./Tests/Bootstrap/test-active-identity.sh
  test ! -e Modules/VulpraRuntime/JIT/JITController.swift
  test ! -d Modules/VulpraRuntime/JIT/Interface
  test ! -e Modules/VulpraRuntime/JIT/RPPairing/libidevice_ffi.a
  ```

  Expected: all commands exit zero.

- [ ] **Commit.** Run:

  ```bash
  git add Modules Tools/Bootstrap docs/provenance Tests/Bootstrap
  git commit -m "feat: import low-level Vulpra JIT substrate"
  ```

## Task 6: Add an explicit substrate boundary report

**Files:** create `docs/provenance/substrate-boundary.md` and extend bootstrap
tests.

**Why:** make the copied/not-copied decision inspectable without reading the
importer implementation.

**Impact/Compatibility:** documentation and verification only.

**Verification:** every manifest target is classified and every forbidden root
is absent.

- [ ] **Write the failing test.** Add a check that every target top-level path in
  `docs/provenance/import-manifest.tsv` is one of `Vendor`, `Patches`, `Tools`,
  `Extensions`, or `Modules`, and require `substrate-boundary.md` to list both
  `Imported` and `Excluded` sections.

- [ ] **Verify RED.** Run the boundary test and expect
  `missing provenance file: docs/provenance/substrate-boundary.md`.

- [ ] **Implement the report.** Record source SHA, imported responsibility
  groups, excluded roots, active identity replacements, permitted attribution/
  patch-name exceptions, and the falsifier: any dependency on excluded client
  code stops the next phase.

- [ ] **Verify GREEN.** Run:

  ```bash
  ./Tests/Bootstrap/test-import-boundary.sh
  awk -F '\t' 'NR > 1 {print $3}' docs/provenance/import-manifest.tsv \
    | cut -d/ -f1 | sort -u
  ```

  Expected top-level output contains only the five approved roots.

- [ ] **Commit.** Run:

  ```bash
  git add docs/provenance Tests/Bootstrap
  git commit -m "docs: record Vulpra substrate boundary"
  ```

## Task 7: Add CI for portable bootstrap verification

**Files:** create `.github/workflows/bootstrap-core.yml`.

**Why:** prevent later feature work from silently importing old client code or
reintroducing old runtime identity.

**Impact/Compatibility:** no Gecko compilation; Ubuntu-only portable checks.

**Verification:** workflow syntax inspection and local command parity.

- [ ] **Write the failing test.** Extend `test-repository-shape.sh` to require
  `.github/workflows/bootstrap-core.yml` and verify it invokes all five portable
  test commands from the Verification section.

- [ ] **Verify RED.** Run the repository shape test and expect a missing workflow
  failure.

- [ ] **Implement the workflow.** Use `ubuntu-latest`, `actions/checkout@v4`
  with `submodules: false`, install no extra packages, and run:

  ```bash
  ./Tests/Bootstrap/test-repository-shape.sh
  ./Tests/Bootstrap/test-repository-shape-nested-parent.sh
  ./Tests/Bootstrap/test-import-boundary.sh
  ./Tests/Bootstrap/test-active-identity.sh
  ./Tools/Gecko/test-gecko-artifact.sh
  find Tools Tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
  git diff --check
  ```

- [ ] **Verify GREEN.** Run the same commands locally and parse the workflow with
  Ruby's built-in YAML parser:

  ```bash
  ruby -e 'require "yaml"; YAML.load_file(".github/workflows/bootstrap-core.yml")'
  ```

  Expected: no output and exit zero.

- [ ] **Commit.** Run:

  ```bash
  git add .github Tests/Bootstrap
  git commit -m "ci: verify Vulpra substrate boundary"
  ```

## Task 8: Run the Phase 0 closeout and record the verified baseline

**Files:** update `docs/aegis/baseline/2026-07-21-initial-baseline.md` and
`docs/aegis/INDEX.md`.

**Why:** convert the empty-repository baseline into a verified substrate
snapshot before planning the Xcode/runtime shell.

**Impact/Compatibility:** documentation only; no release-readiness claim.

**Verification:** all portable gates, clean Git status, manifest/source SHA, and
forbidden-root searches.

- [ ] **Write the failing test.** Extend `test-repository-shape.sh` to require the
  baseline status `substrate-import-verified` and an index entry for
  `docs/provenance/substrate-boundary.md`.

- [ ] **Verify RED.** Run the shape test and expect a baseline-status failure.

- [ ] **Implement the closeout.** Update the baseline with the exact submodule
  SHAs, imported file count, manifest hash, active identity map, excluded roots,
  passing command list, missing macOS/Xcode evidence, and next-plan boundary.
  Add the provenance entry to `docs/aegis/INDEX.md`.

- [ ] **Verify GREEN.** Run:

  ```bash
  ./Tests/Bootstrap/test-repository-shape.sh
  ./Tests/Bootstrap/test-import-boundary.sh
  ./Tests/Bootstrap/test-active-identity.sh
  ./Tools/Gecko/test-gecko-artifact.sh
  find Tools Tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
  git diff --check
  git status --short
  ```

  Expected: all tests pass. Before committing, status contains only baseline and
  index changes.

- [ ] **Commit.** Run:

  ```bash
  git add docs/aegis
  git commit -m "docs: baseline verified Vulpra substrate"
  git status --short
  ```

  Expected final status: empty.

## Follow-up Plan Sequence

Phase 0 completion authorizes planning, not automatic execution, of these
separate workstreams:

1. `vulpra-runtime-shell`: new Xcode graph, Vulpra app/Helper/OpenIn targets,
   Gecko framework linking, JIT orchestration, and first unsigned iOS 15+ IPA.
2. `vulpra-tabs-and-data`: tab/session domain, new schema version 1, private-tab
   boundary, lifecycle recovery, and transactional persistence.
3. `vulpra-browser-ui`: address bar, navigation, phone tab grid, iPad sidebar,
   homepage, design system, accessibility, and 60/120 Hz interaction.
4. `vulpra-library-and-web-input`: bookmarks, history, downloads, file/select/
   date/color prompts, context menus, media, and picture-in-picture.
5. `vulpra-power-features`: add-ons, permissions, user scripts, blocking, night
   mode, translation, user-agent/language/compatibility, and toolbar policy.
6. `vulpra-reliability-and-release`: diagnostics, backup/restore, data clearing,
   Gecko artifact CI, IPA/TIPA/Jailbroken packaging, iOS 15.8/16.7 device gates,
   ADRs, and final baseline sync.

Each follow-up plan must cite the verified Phase 0 manifest and may not broaden
the import boundary without a design amendment.

## Risks

- Imported runtime files may depend on generated Gecko headers unavailable on
  Linux; Phase 0 verifies boundaries, not compilation.
- Changing the XPC endpoint key requires the corresponding Gecko patch and
  Helper code to remain synchronized.
- Some low-level patch symbols retain historical Reynard names. They are allowed
  only when listed in provenance and are not active product identity.
- Source-file copyright comments must not be removed merely to satisfy a broad
  text search.
- The current source commit may contain a hidden Xcode membership dependency;
  discovering one in the next phase triggers dependency classification rather
  than broad copying.

## Retirement

### Repair Track

- **Root cause:** the existing repository combines a valuable Gecko/iOS
  substrate with an inherited browser product the user does not want to retain.
- **Canonical owner:** the new repository import manifest and Vulpra modules.
- **Minimal sufficient stable repair:** fresh history plus pinned allowlisted
  extraction.
- **Compatibility boundary:** preserve engine/process/JIT mechanics, not product
  code or user data.
- **Verification:** manifest, forbidden-root, active-identity, artifact, and
  clean-status checks.

### Retirement Track

- **Old owner/fallback:** old client, UI, stores, app target, resources, and JIT
  presentation.
- **Active status:** source repository remains available only as reference.
- **Keep reason:** none inside Vulpra.
- **Deletion trigger:** non-import is immediate; accidental imports are removed
  before the affected task commit.
- **Compat retained:** no.

## ADR and Baseline Signals

- Preserve the design's ADR signals for substrate provenance, runtime/client
  ownership, no-migration persistence, and artifact/package ownership.
- After the first macOS-linked Vulpra IPA exists, record the substrate and
  runtime ownership ADR from verified work.
- Do not claim the full browser, release, or device gate complete at Phase 0.
