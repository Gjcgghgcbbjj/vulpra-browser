# Vulpra Runtime Shell - Checkpoint

- Task ID: 2026-07-22-vulpra-runtime-shell
- Current todo: Write and review the Phase 1 runtime-shell design specification.
- Active slice: Design specification
- Blocked on: Mac/Xcode evidence is deferred by user choice, not blocking Phase 1A.
- Next step: Write the approved native-Xcode design, self-review it, commit it, and request written-spec approval.

## Checkpoint Update

- Current todo: Obtain user approval of the committed Phase 1A written design, then transition to implementation planning.
- Active slice: Written design review gate
- Completed todos:
- Explored the verified baseline, source Xcode graph, Gecko/JIT/Helper contracts, artifact state, and Linux host capability.
- User selected no-current-Mac Phase 1A/Phase 1B evidence split and approved the fresh native Xcode project approach.
- Written design specification completed and self-reviewed.
- Evidence refs:
- docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md
- Blocked on: User written-spec review is required before implementation planning.
- Next step: Commit the design/work records and ask the user to approve or request changes.

## DriftCheckDraft

- Scope status: Design remains limited to runtime shell Phase 1A and Mac producer contracts; tabs/data/final browser UI/features remain excluded.
- Compatibility status: iOS 15.0, TrollStore-first, exact Vulpra identities, no old client/data/Xcode fallback, and explicit Mac needs-verification boundary are preserved.
- Retirement status: Old project/client/JIT controller/release scripts remain retired by non-copy; the runtime smoke shell has a named future retirement owner.
- New risk signals:
- The compact synchronized-group pbxproj design depends on modern Xcode semantic validation that cannot run on Linux.
- Advisory decision: pause-for-user

## Checkpoint Update

- Current todo: Execute Task 1: create and verify the fresh Xcode graph and configuration owners.
- Active slice: Task 1 Xcode graph RED/GREEN implementation
- Completed todos:
- Approved runtime-shell design committed and user-confirmed.
- Ten-task Phase 1A implementation plan written and self-reviewed.
- Evidence refs:
- docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md
- docs/aegis/plans/2026-07-22-vulpra-runtime-shell.md
- Blocked on: Mac/Xcode compilation evidence remains deferred to Phase 1B and does not block portable Task 1.
- Next step: Commit the approved plan, write the failing Xcode graph test, verify RED, then implement the minimal graph under the 800-line budget.

## DriftCheckDraft

- Scope status: Planning remains limited to Phase 1A runtime shell and producer contracts; tabs, data, final UI, and release claims remain excluded.
- Compatibility status: iOS 15.0, arm64, TrollStore-first, no old identity/data/Xcode fallback, and Mac evidence deferral remain intact.
- Retirement status: Old client/project/JIT UI/release owners remain absent; RuntimeShellViewController remains an explicitly temporary smoke owner.
- New risk signals:
- Hand-authored objectVersion 77 synchronized groups require later validation by current Xcode.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 2: add app metadata, entitlement profiles, and pure URL routing.
- Active slice: Task 2 product identity and URL input contracts
- Completed todos:
- Approved runtime-shell design and ten-task implementation plan.
- Task 1 fresh Xcode graph and configuration owners pass portable RED/GREEN verification.
- Evidence refs:
- Tests/RuntimeShell/test-xcode-graph.py
- Vulpra.xcodeproj/project.pbxproj
- Configuration/Base.xcconfig
- Vulpra.xcodeproj/xcshareddata/xcschemes/Vulpra.xcscheme
- Blocked on: Current Xcode semantic acceptance remains Phase 1B needs-verification; no Phase 1A blocker.
- Next step: Commit Task 1, then write the failing product-contract test before creating App/Info.plist, entitlements, and RuntimeURLRouter.swift.

## DriftCheckDraft

- Scope status: Task 1 added only the fresh project/configuration owners and structural test; no browser UI, data, or old client code entered.
- Compatibility status: iOS 15.0, arm64, iPhone/iPad, TrollStore-first future entitlements, generated .build/dist roots, and no signing team remain explicit.
- Retirement status: The old Xcode project remains absent; synchronized groups and xcconfigs are the sole new graph/settings owners.
- New risk signals:
- The hand-authored objectVersion 77 graph still requires current-Xcode validation in Phase 1B.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 3: implement the minimal UIKit Gecko runtime shell.
- Active slice: Task 3 one-session UIKit Gecko smoke owner
- Completed todos:
- Task 1 fresh Xcode graph and configuration owners.
- Task 2 product metadata, entitlement profiles, Helper entitlement retirement, and pure URL router pass portable verification.
- Evidence refs:
- Tests/RuntimeShell/test-product-contracts.py
- App/Info.plist
- App/RuntimeURLRouter.swift
- docs/provenance/import-manifest.tsv
- Blocked on: Swift/UIKit/Gecko compilation remains Phase 1B needs-verification; source-contract work can continue.
- Next step: Commit Task 2, then write the failing runtime-shell test before adding main, app delegate, scene delegate, and one-session view controller.

## DriftCheckDraft

- Scope status: Task 2 added identity/input contracts only; no Gecko session, tabs, persistence, settings, or final browser UI.
- Compatibility status: Exact Vulpra identities, iOS 15 families, one URL scheme, minimal private permissions, and no old identity/data fallback remain intact.
- Retirement status: get-task-allow and uncertain web-browser/persona/storage permissions are absent; URL routing has one canonical pure owner.
- New risk signals:
- Private entitlement acceptance remains device/signing evidence for Phase 1B.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 4: add the exactly-once JIT readiness owner and bridge cleanup.
- Active slice: Task 4 exactly-once child JIT readiness orchestration
- Completed todos:
- Task 1 fresh Xcode graph and configuration owners.
- Task 2 product metadata, entitlement profiles, and URL router.
- Task 3 minimal one-session UIKit Gecko runtime shell, canonical missing-engine handling, and AppDelegate owner correction.
- Evidence refs:
- Tests/RuntimeShell/test-runtime-shell.py
- App/RuntimeShellViewController.swift
- Extensions/GeckoView/Session/GeckoSession.swift
- docs/aegis/specs/2026-07-22-vulpra-runtime-shell-design.md
- Blocked on: RuntimeJITCoordinator and bridging header are not implemented yet; Mac compilation remains deferred.
- Next step: Commit Task 3, then write the failing JIT orchestration/header-closure test before creating RuntimeJITCoordinator and the bridging header.

## DriftCheckDraft

- Scope status: Task 3 remains one-session smoke integration; no tab, data, settings, downloads, prompt UI, or final chrome owner was added.
- Compatibility status: Static scene manifest composes with Gecko AppShellDelegate; iOS 15 identities and URL contract remain unchanged; missing view degrades visibly without renderer fallback.
- Retirement status: The planned dead AppDelegate owner is retired before creation; GeckoSession fatal path is retired in favor of the canonical App failure owner; old source project remains rejected.
- New risk signals:
- Static scene-manifest behavior and the adjusted GeckoSession path still require Xcode/device evidence in Phase 1B.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 5: add the new OpenIn extension owner.
- Active slice: Task 5 one-path OpenIn URL delivery extension
- Completed todos:
- Tasks 1-3 fresh graph, product contracts, and minimal one-session runtime shell.
- Task 4 exactly-once JIT readiness coordinator, minimal bridge, public ExtensionBridge header, and TSUtils retirement.
- Evidence refs:
- Tests/RuntimeShell/test-jit-orchestration.py
- App/RuntimeJITCoordinator.swift
- App/Bridging/Vulpra-Bridging-Header.h
- docs/provenance/import-manifest.tsv
- Blocked on: JIT attachment and C/Swift bridge compilation remain Phase 1B needs-verification; no portable blocker.
- Next step: Commit Task 4, then write the failing OpenIn contract test before creating its plist and one-path NSExtensionContext.open implementation.

## DriftCheckDraft

- Scope status: Task 4 added only child readiness orchestration and bridge cleanup; no JIT settings, failure UI, retry policy, or diagnostics owner.
- Compatibility status: Every accepted positive PID receives at most one explicit status; tab-only attachment and hasTXMSupport false preserve the approved iOS 15/TrollStore boundary.
- Retirement status: TSUtils import is deleted with no shim; old JITController/UI/prefs paths remain absent; one finish function owns all reports.
- New risk signals:
- Swift/C header and timing behavior require current Xcode plus physical-device evidence.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 6: govern Gecko and idevice artifact production.
- Active slice: Task 6 deterministic macOS runtime substrate producers and artifact v3
- Completed todos:
- Tasks 1-4 graph, product/runtime, and exactly-once JIT contracts.
- Task 5 new one-path OpenIn share extension passes portable verification.
- Evidence refs:
- Tests/RuntimeShell/test-open-in.py
- Extensions/OpenIn/Info.plist
- Extensions/OpenIn/OpenInViewController.swift
- Blocked on: Physical-device host opening remains Phase 1B needs-verification; producer contract work can continue on Linux.
- Next step: Commit Task 5, then write failing runtime-artifact tests for iOS 15, .build idevice output, format v3 Xcode/SDK fingerprints, and needs-macos behavior.

## DriftCheckDraft

- Scope status: Task 5 added only URL handoff; no browser UI, persistence, alternate opener, or old extension source.
- Compatibility status: One shared http/https URL maps to the existing vulpra://open router contract; public API remains the sole path.
- Retirement status: Old OpenIn implementation and all private/responder fallbacks remain absent; device failure is still the only amendment trigger.
- New risk signals:
- Host-opening success is device-only evidence and remains explicitly open.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 7: add archive, ptrace, IPA, and TIPA producers.
- Active slice: Task 7 deterministic archive and portable package producers
- Completed todos:
- Tasks 1-5 graph, runtime, JIT, and OpenIn contracts.
- Task 6 deterministic macOS runtime substrate producer, artifact v3, and generated-output governance.
- Evidence refs:
- Tests/RuntimeShell/test-runtime-artifacts.sh
- Tools/Runtime/build-runtime-substrate.sh
- Tools/Gecko/gecko-artifact.sh
- docs/provenance/import-manifest.tsv
- Blocked on: Actual Gecko/idevice production requires macOS and remains unexecuted; portable packaging fixtures can continue.
- Next step: Commit Task 6, then write the failing release-packaging fixture before creating build-app, build-ptrace-jit, package-app, and create-ipa scripts.

## DriftCheckDraft

- Scope status: Task 6 changed producer contracts only; Linux did not fetch, build, or generate runtime payloads.
- Compatibility status: iOS 15.0 and canonical .build/dist roots are explicit; Xcode remains a verifier/consumer rather than a silent producer.
- Retirement status: iOS 13 settings, Modules idevice output, artifact v2, stale SDK acceptance, and escaping AddGecko path are deleted with no compatibility copies.
- New risk signals:
- The macOS producer sequence and real generated header layout still require Phase 1B execution.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 8: add the canonical portable runtime-shell gate.
- Active slice: Task 8 one portable runner and existing CI workflow integration
- Completed todos:
- Tasks 1-6 graph/runtime/JIT/OpenIn and runtime artifact producers.
- Task 7 deterministic archive, ptrace, IPA, and TIPA producer contracts.
- Evidence refs:
- Tests/RuntimeShell/test-release-packaging.sh
- Tools/Release/package-app.sh
- Blocked on: Real archive/sign/package execution remains Phase 1B; portable CI integration can continue.
- Next step: Commit Task 7, then make repository shape fail for missing run-portable.sh/workflow invocation and implement the canonical runner.

## DriftCheckDraft

- Scope status: Task 7 added producer scripts and fixtures only; no release artifact or signing identity entered Git.
- Compatibility status: Packaging consumes exact Vulpra products from a copied stage and preserves the unsigned archive; iOS 15 ptrace and private entitlement paths are explicit.
- Retirement status: Old release workflow remains absent; bundle rewriting and archive mutation are forbidden rather than retained as compatibility.
- New risk signals:
- Actual executable names, ldid signatures, and TrollStore install require Phase 1B evidence.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 9: record the Phase 1A portable baseline and architecture decision.
- Active slice: Task 9 portable baseline, ADR, index, build handoff, and work closeout records
- Completed todos:
- Tasks 1-7 runtime shell and producer implementation.
- Task 8 one canonical portable RuntimeShell gate integrated into existing dependency-free Ubuntu workflow.
- Evidence refs:
- Tests/RuntimeShell/run-portable.sh
- .github/workflows/bootstrap-core.yml
- Blocked on: Mac/Xcode/IPA/device/performance evidence remains explicitly open; documentation closeout can proceed.
- Next step: Commit Task 8, then extend shape expectations for a runtime-shell-portable-verified baseline and create the baseline/ADR with exact current evidence.

## DriftCheckDraft

- Scope status: Task 8 consolidated verification only; no second workflow, dependency, or runtime behavior was added.
- Compatibility status: Portable/Mac evidence split remains explicit and Ubuntu remains submodule-free.
- Retirement status: Duplicated workflow-level artifact/syntax commands are replaced by the canonical runner; Bootstrap tests remain direct prerequisites.
- New risk signals:
- GitHub-hosted execution remains unobserved because this repository has no configured remote.
- Advisory decision: continue

## Checkpoint Update

- Current todo: Execute Task 10: run the final Phase 1A portable closeout at the exact final commit.
- Active slice: Task 10 fresh full-gate verification and clean-worktree handoff
- Completed todos:
- Tasks 1-8 implementation and canonical portable gate.
- Task 9 runtime-shell-portable-verified baseline, ADR-0002, README Mac handoff, indexed work reflection.
- Evidence refs:
- docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md
- docs/aegis/adr/ADR-0002-runtime-shell-ownership-and-evidence-boundary.md
- Blocked on: Phase 1B Apple-platform evidence remains external but does not block Phase 1A portable closeout.
- Next step: Commit Task 9, then run every Bootstrap/runtime/artifact/syntax/identity/manifest/complexity/Aegis/hygiene check against the final feature commit.

## DriftCheckDraft

- Scope status: Task 9 documents implemented Phase 1A owners and evidence only; later browser UI/data work remains excluded.
- Compatibility status: Baseline preserves iOS 15 arm64 TrollStore-first compatibility and labels every Mac/device/performance fact needs-verification.
- Retirement status: ADR and reflection preserve the explicit retirement of old project/client/fallbacks and the future runtime-shell replacement trigger.
- New risk signals:
- No new risk beyond the recorded Phase 1B Apple-platform and publication gates.
- Advisory decision: continue
