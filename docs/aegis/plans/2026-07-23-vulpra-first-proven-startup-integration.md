# Vulpra-First Proven Startup Integration Plan

Date: `2026-07-23`
Status: `approved-for-inline-execution`
ArchitectureReviewRequired: `yes`
TDD Route: `light`

## Goal

Make the clean Vulpra repository the only product owner. Import the existing
Vulpra-authored browser client and fresh Xcode graph, retain only the audited
GeckoView/Helper/JIT substrate lineage, and borrow the smallest verified launch,
embedding, signing, and packaging contracts needed from the bootable Reynard
reference without copying its client, resources, data owners, or project.

## Architecture

- `App/`, `Configuration/`, `Extensions/OpenIn/`, `Vulpra.xcodeproj`, browser
  tests, release scripts, product workflows, UI, stores, and resources are
  Vulpra-owned.
- `Extensions/GeckoView/`, `Extensions/Helper/`, `Modules/VulpraRuntime/`,
  `Patches/`, and the imported Gecko build tools remain substrate-derived and
  provenance-tracked.
- `/root/reynard-browser` is evidence-only. No file is copied from its client,
  resources, or Xcode project during this integration.
- The known-good target graph is used as a checklist of runtime contracts, not
  as a product source tree.

## Tech Stack

UIKit, Swift, Objective-C/Objective-C++, GeckoView, Xcode native project files,
shell/Python portable checks, and GitHub Actions macOS producers.

## Baseline / Authority Refs

- `docs/aegis/baseline/2026-07-21-initial-baseline.md`
- `docs/aegis/adr/ADR-0001-phase-0-substrate-ownership-boundary.md`
- `docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md`
- `docs/provenance/substrate-boundary.md`
- `docs/aegis/policies/efficiency-complexity-governance.md`
- approved Vulpra runtime-shell and modern-browser specifications from commit
  `7955722ce68f63e4f470837947cfdde385458b13`
- bootable reference contract at Reynard commit
  `3dea55d` (inspection only)

## Compatibility Boundary

- iOS deployment target remains `15.0`, arm64, iPhone and iPad.
- Product identities remain `com.vulpra.browser`,
  `com.vulpra.browser.geckoview`, `com.vulpra.browser.helper`, and
  `com.vulpra.browser.open-in`.
- Helper product remains `Vulpra Helper.appex`, principal class
  `VulpraHelperMain`, endpoint `VulpraXPCListenerEndpoint`.
- Existing verified runtime artifact may be reused only when the exact runtime
  key and Xcode/SDK fingerprints match.
- No old installation data, database, preference domain, resource, or product
  compatibility fallback is introduced.

## Verification

Portable verification covers ownership, identity, source boundaries, Xcode
graph contracts, scripts, plist parsing, complexity, and deterministic
packaging. GitHub macOS verification covers archive/IPA/TIPA creation and
unpacked bundle checks. Physical-device launch remains a separate user-confirmed
gate and is never inferred from an Actions success.

## Plan Basis

The original Phase 0 decision already rejected “copy Reynard then delete.” The
current correction restores that decision: use the clean Vulpra history as the
canonical base and select only independently owned product files plus explicit
substrate deltas.

### BaselineUsageDraft

- Required refs: initial baseline, ADR-0001, substrate boundary, complexity
  policy.
- Acknowledged before plan: all required refs.
- Cited in plan: all required refs.
- Missing refs: fresh GitHub package build and physical-device launch evidence.
- Decision: `continue`; device result remains `needs-verification`.

### Requirement Ready Check

- Requirement source: current user correction plus the approved Vulpra product
  specifications.
- Goal/scope: Vulpra-first ownership with borrowed substrate contracts only.
- Acceptance: product-boundary tests, portable gates, GitHub package evidence,
  unpacked artifact verification.
- Open blocker: none for implementation; physical-device evidence is external.
- Decision: `ready`.

### Architecture Integrity Lens

- Invariant: Vulpra owns every product concern; derived substrate owns only
  engine/process/JIT integration.
- Canonical product owner: this repository and its fresh four-target project.
- Responsibility overlap: none retained; Reynard is not a build input.
- Higher-level simplification: transfer Vulpra-owned files by allowlist instead
  of merging unrelated Git history.
- Falsifier: any required dependency on Reynard Client/Resources/old stores.
- Verdict: proceed with delete-first retirement of the wrong product path.

### Anti-Entropy Declaration

- Deletion class: code-retirement.
- Old path: Reynard project acting as Vulpra product owner.
- New canonical owner: `/root/vulpra-browser`.
- Preserved behavior: Gecko launch, Helper/JIT handshake, signing and embedding
  contracts.
- Retired behavior: Reynard UI, resources, stores, old project and release
  ownership.
- External boundary touched: GitHub artifacts and iOS package format only.
- Source-of-truth data risk: none.
- User confirmation required: no.

### Complexity Budget

- Product Swift target: no owner above 350 lines; current maximum candidate is
  270 lines.
- Xcode graph target: below 800 lines; current candidate is about 263 lines.
- Runtime/release scripts: below 250 lines each.
- Third-party product dependencies: zero.
- Product source and resources are measured separately from Gecko/vendor and
  generated packages.
- Budget result: `within-budget`, with source-provenance review required for
  short interface-contract files.

## Task 1: Establish Product Ownership and Provenance Gates

**Files**

- Create `Tests/Ownership/test-product-boundary.py`
- Create `Tests/Ownership/run-portable.sh`
- Create `docs/provenance/product-boundary.md`
- Create `docs/provenance/substrate-deltas.tsv`
- Modify `.github/workflows/bootstrap-core.yml`

**Why**

Make “Vulpra is the product; Reynard is reference-only” executable rather than
relying on naming or intent.

**Impact / Compatibility**

No runtime change. The test must reject old product identity, source-client
paths, imported-product manifest rows, generated binaries, and copied resource
roots while allowing explicit historical provenance in substrate files.

**Verification**

```bash
python3 Tests/Ownership/test-product-boundary.py
bash -n Tests/Ownership/run-portable.sh
```

- [x] Write the ownership test before product import.
- [x] Run it and confirm RED because the product roots are not present yet.
- [x] Add the boundary document and substrate-delta schema.
- [x] Re-run after Task 2 and confirm GREEN.
- [x] Commit the independently reviewable ownership slice.

## Task 2: Import Only Vulpra-Owned Product Files

**Files**

- Create `App/**`, `Configuration/**`, `Extensions/OpenIn/**`
- Create `Vulpra.xcodeproj/**`
- Create `Tools/Runtime/**`, `Tools/Release/**`
- Create `Tests/RuntimeShell/**`, `Tests/Browser/**`
- Create product GitHub workflows, excluding the temporary diagnostic IPA and
  placeholder-only simulator shell workflows
- Create approved Vulpra product specification documents

**Why**

Reuse already authored Vulpra work without making the old project or history a
product dependency.

**Impact / Compatibility**

Transfer from Vulpra commit `7955722` by explicit path allowlist. Exclude
`__pycache__`, `.pyc`, generated outputs, old work evidence, old baselines,
diagnostic-only workflow, and any path containing inherited product identity.

**Verification**

```bash
Tests/Ownership/run-portable.sh
Tests/RuntimeShell/run-portable.sh
Tests/Browser/run-portable.sh
rg -n -i 'Reynard|com\.minh-ton|BrowserCore|StabilityCore' App Configuration Extensions/OpenIn Vulpra.xcodeproj Tools/Runtime Tools/Release
```

- [x] Keep the ownership gate RED before transfer.
- [x] Copy only the enumerated Vulpra-owned roots.
- [x] Change `AtomicJSONStore` from `final class` to `struct`.
- [x] Replace diagnostic startup branches with the minimal JIT then Gecko main.
- [x] Run product gates GREEN and commit.

## Task 3: Integrate Necessary Substrate Deltas Without Product Leakage

**Files**

- Modify the audited GeckoView/Helper files required for recoverable startup,
  iOS 15 feature settings, Helper metadata, and JIT/build output locations
- Modify `Tools/Build/AddGecko.sh` and selected `Tools/Gecko/**`
- Create `Tools/Runtime/build-gecko-simulator.sh`
- Modify `docs/provenance/import-manifest.tsv`
- Populate `docs/provenance/substrate-deltas.tsv`
- Modify Phase 0 tests only where Vulpra-owned generated-output boundaries have
  legitimately changed

**Why**

Keep engine-derived code visibly derived while allowing Vulpra-maintained
stability and producer fixes.

**Impact / Compatibility**

No client/UI code enters a substrate root. New Vulpra-authored tools live under
`Tools/Runtime`, not inside the exact imported `Tools/Gecko` inventory. Every
changed imported file records its clean-baseline hash, new hash, and reason.

**Verification**

```bash
./Tests/Bootstrap/test-gecko-substrate.sh
./Tests/Bootstrap/test-active-identity.sh
./Tests/Bootstrap/test-jit-substrate.sh
./Tools/Gecko/test-gecko-artifact.sh
```

- [x] Add/adjust failing contract assertions for `.build/idevice` and delta
  coverage.
- [x] Confirm RED against the clean substrate.
- [x] Apply only the reviewed runtime-branch deltas.
- [x] Update target hashes and delta provenance, then confirm GREEN.
- [x] Commit the substrate delta slice separately.

## Task 4: Repair the Fresh Xcode Graph from Verified Runtime Contracts

**Files**

- Modify `Vulpra.xcodeproj/project.pbxproj`
- Modify `Configuration/*.xcconfig`
- Modify Vulpra/Helper/OpenIn plist and entitlement files as required
- Modify `Tests/RuntimeShell/test-xcode-graph.py`
- Modify release packaging checks

**Why**

The fresh project must boot and package correctly without copying the working
Reynard project.

**Impact / Compatibility**

Compare target graph, runpaths, search paths, linker flags, bridging header,
extension API setting, Helper package type/principal class, embed order,
entitlements, and signing order. Transfer only setting values whose necessity
is demonstrated by the working contract.

**Verification**

```bash
python3 Tests/RuntimeShell/test-xcode-graph.py
python3 Tests/RuntimeShell/test-product-contracts.py
./Tests/RuntimeShell/test-release-packaging.sh
```

- [x] Expand the graph tests for each verified runtime contract.
- [x] Run RED for every missing/mismatched contract.
- [x] Apply minimal fresh-project settings, never project-file copying.
- [x] Run GREEN and inspect the final graph diff.
- [x] Commit the launch/package contract slice.

## Task 5: Verify Complexity, Identity, and Portable Integration

**Files**

- Modify portable workflow/test aggregators as needed
- Create `docs/aegis/baseline/2026-07-23-vulpra-first-portable-baseline.md`
- Create `docs/aegis/adr/ADR-0002-vulpra-first-product-integration.md`

**Why**

Prove the result is an efficient Vulpra product and that old owners are absent.

**Verification**

```bash
./Tests/Bootstrap/test-repository-shape.sh
./Tests/Bootstrap/test-repository-shape-nested-parent.sh
./Tests/Bootstrap/test-import-boundary.sh
./Tests/Bootstrap/test-gecko-substrate.sh
./Tests/Bootstrap/test-active-identity.sh
./Tests/Bootstrap/test-jit-substrate.sh
./Tests/Ownership/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
find Tools Tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
git diff --check
```

- [x] Run the full gate and collect failures.
- [x] Classify every failure as ownership, missing owner logic, stale consumer,
  or baseline drift.
- [x] Fix at the canonical owner without compatibility fallbacks.
- [x] Record source-line, largest-owner, dependency, and generated-output
  measurements.
- [x] Commit the verified portable baseline and ADR.

## Task 6: Build and Verify GitHub IPA/TIPA Artifacts

**Files**

- Modify `.github/workflows/build-ios-packages.yml` only if exact artifact
  restoration requires correction
- No committed binary output

**Why**

Validate the Mac/Xcode-owned build path while reusing the exact runtime
substrate instead of rebuilding Gecko unnecessarily.

**Impact / Compatibility**

Push the integration branch first. Do not rewrite remote `main` until the
branch passes portable and package gates. Actions success proves package
creation, not physical-device launch.

**Verification**

```bash
gh workflow run build-ios-packages.yml --repo Gjcgghgcbbjj/vulpra-browser --ref feature/vulpra-first-integration
gh run watch --repo Gjcgghgcbbjj/vulpra-browser <run-id> --exit-status
```

- [x] Push the verified integration branch.
- [x] Dispatch the package workflow using the matching runtime artifact.
- [x] Monitor to terminal success or repair a real failure.
- [x] Download and unpack the artifact; verify bundle IDs, embedded framework,
  Helper/OpenIn extensions, executable files, and checksums.
- [x] Record run URL, commit, artifact IDs, sizes, and hashes.

## Task 7: Deliver the Windows Desktop Test Package

**Files**

- External generated package only; no repository file change

**Why**

Provide the user one unambiguous current test package.

**Verification**

```bash
sha256sum <downloaded-package>
unzip -t <downloaded-package>
```

- [x] Locate the mounted Windows desktop path.
- [x] Stage the new package beside the destination.
- [x] Verify checksum and archive integrity.
- [x] Atomically replace the prior Vulpra test package.
- [x] Report the exact desktop path and retain device launch as
  `needs-user-verification`.

## Execution Closeout

- Verified package commit:
  `5f49f3cdd62221b1bc9bb5be149b5c1be4922491`.
- Bootstrap Core run `29961240711`: `success`.
- Build Vulpra IPA and TIPA run `29961256526`: `success`.
- Installable artifact ID: `8546130042`.
- Package hashes and structural verification:
  `docs/aegis/work/2026-07-23-vulpra-first-integration/evidence-bundle-draft-package-verification-29961256526.json`.
- Delivered path:
  `/mnt/c/Users/niting/Desktop/Vulpra-Fixed-29944288468`.
- Physical-device installation and launch remain
  `needs-user-verification`, as required by the plan boundary.

## Risks and Stop Conditions

- A required dependency on Reynard Client/Resources/stores stops integration
  for architecture review.
- A runtime artifact key mismatch triggers an exact runtime rebuild; it never
  permits using a stale artifact.
- An Xcode compile failure is repaired at the fresh Vulpra owner or real
  substrate contract, not by copying the old project.
- Any maintained owner over budget must be split or explicitly governed before
  completion.
- Physical-device opening is not claimed until the user installs and confirms
  it.

## Retirement

The wrong Reynard-product route is retired immediately. No compatibility
wrapper, second project owner, duplicated client tree, or renamed old resource
bundle remains. The old repository stays read-only solely for contract
comparison.
