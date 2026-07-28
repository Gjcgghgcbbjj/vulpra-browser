# Vulpra Independent Engine Completion and IPA - Evidence

No evidence has been recorded yet.

## EvidenceBundleDraft

- Artifact key: simulator-visible-navigation-30213751790
- Type: github-actions-runtime
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30213751790
- Summary: Xcode 26.4.1 build, launch, one queued HTTPS LoadUri, native view attach before dispatch, visible Example Domain content with 40077 dark pixels, page completion, Engine Process connections, survival, and zero crashes.
- Verifier: Workflow assertions plus downloaded logs and screenshot inspection.

## EvidenceBundleDraft

- Artifact key: candidate-package-30214371123
- Type: github-actions-package
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30214371123
- Summary: Xcode archive, IPA/TIPA creation, artifact-backed signing-independent Mach-O content validation, signature checks, SHA256SUMS, and artifact upload passed.
- Verifier: .github/workflows/build-ios-packages.yml and uploaded validation logs.

## EvidenceBundleDraft

- Artifact key: portable-cutover-gates
- Type: local-verification
- Source: Tests/IndependentEngine/run-portable.sh; Tests/RuntimeShell/run-portable.sh; Tests/Browser/run-portable.sh
- Summary: Ownership, ABI, message, public contract, Xcode graph, package, browser client, plist, and negative retirement gates passed; cutover readiness reports ready.
- Verifier: Portable test runners and git diff --check.

## EvidenceBundleDraft

- Artifact key: retirement-boundary
- Type: architecture-retirement
- Source: Configuration/engine-ownership.json
- Summary: One VulpraEngineKit adapter remains; GeckoView, Helper, JIT, Patches, Gecko source workflows, Firefox/idevice gitlinks, and fallbacks are retired without deleting user data.
- Verifier: Ownership/internal-boundary tests, Xcode graph test, and repository scans.

## EvidenceBundleDraft

- Artifact key: final-package-30215026323
- Type: final-package
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30215026323
- Summary: Metadata-complete snapshot 23dd018873ff64c696e0a4c05ee9095e406c01f0 archived and produced final Vulpra.ipa and Vulpra-TrollStore.tipa; workflow and local SHA256, ZIP, bundle, artifact, Mach-O content, and signature validations passed.
- Verifier: dist/SHA256SUMS; Tools/Engine/validate-ipa.py; unzip -t; GitHub Actions run 30215026323.

## EvidenceBundleDraft

- Artifact key: final-runtime-package-identity-simulator-30239461150
- Type: github-actions-runtime
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30239461150
- Summary: Snapshot 95338aad built 0.2.0 (2), passed both native EngineKit XCTest cases, rendered the Chinese Porcelain start page, navigated to Example Domain for 60 seconds, connected Engine Process, and produced no crash.
- Verifier: .github/workflows/simulator-smoke.yml; downloaded logs and screenshots; manual screenshot inspection.

## EvidenceBundleDraft

- Artifact key: final-runtime-package-identity-package-30240301567
- Type: final-package
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30240301567
- Summary: The same snapshot produced validated Vulpra.ipa and Vulpra-TrollStore.tipa at 0.2.0 (2) with porcelain-zh-v2-20260727 in plist and executable; desktop and dist hashes match.
- Verifier: Tools/Engine/validate-ipa.py; unzip -t; SHA256SUMS; structured plist and ZIP inspection.

## EvidenceBundleDraft

- Artifact key: integrated-client-preflight-30287131207
- Type: preliminary-simulator
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30287131207
- Summary: Snapshot a751acd passed Xcode compilation and all six then-current EngineKit tests and produced a Chinese icon-first Porcelain start-page screenshot. The run stopped when bounded `simctl terminate` timed out before the isolated navigation launch, so it is compile/test/UI evidence rather than final runtime evidence.
- Verifier: downloaded simulator build/native-test logs and manual review of `/root/.cache/vulpra-simulator-30287131207/simulator-start-page.png`.

## EvidenceBundleDraft

- Artifact key: final-package-delivery-30398876901
- Type: final-package
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30398876901; dist/SHA256SUMS; /mnt/c/Users/niting/Desktop/Vulpra/SHA256SUMS
- Summary: Snapshot ac5e6ff passed all portable gates and the Xcode archive/package workflow, producing Vulpra.ipa and Vulpra-TrollStore.tipa at 0.2.0 (4) with porcelain-zh-v4-20260728. Local validation confirmed 2671 files per package, correct bundle/artifact/profile/signatures/fingerprint, no retired payload, and SHA-256 c61435d2bd196cc49ec9cf054b318191a12d7fa7944c8b02e2bba7f0a53f553b for IPA and 2228d83ba84feee717fccf5704110b9b4030b5a1cb0edd1458952b8aa1de5484 for TIPA.
- Verifier: GitHub Actions run 30398876901; Tools/Engine/validate-ipa.py including --require-signatures for TIPA; unzip -t; sha256sum -c; structured ZIP, plist, Mach-O, and payload inspection.

## EvidenceBundleDraft

- Artifact key: loopback-executable-rendering-30389904599
- Type: historical-simulator-executable
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30389904599; /root/.cache/vulpra-simulator-30389904599/vulpra-independent-simulator-30389904599/
- Summary: The iOS 26.4 run at f52adf04 fetched the loopback fixture twice, logged Engine location http://127.0.0.1:8765/ and Engine page completed true, created multiple Engine Process connections, remained alive without a crash, and visibly rendered Vulpra Engine Ready. Recalibrating the screenshot scan to height/12..<height/8 finds 12266 dark pixels versus 0 for the current blank screenshot. The run's overall conclusion remained failure because its older pixel band missed the rendered heading. App, EngineKit, configuration, tools, portable engine/runtime tests, and package workflow inputs are identical between f52adf04 and ac5e6ff.
- Verifier: Downloaded fixture/system/survival/crash logs, simulator-navigation.png inspection, deterministic pixel recount, and git diff --quiet f52adf04 ac5e6ff over runtime/package-owned paths.

## EvidenceBundleDraft

- Artifact key: hosted-simulator-rerun-drift-30393594180-30397230869
- Type: needs-verification
- Source: https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30393594180; https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30395172252; https://github.com/Gjcgghgcbbjj/vulpra-browser/actions/runs/30397230869
- Summary: Three bounded formal reruns all built successfully, passed seven native EngineKit tests, kept Vulpra alive, and produced no crash. Run 30393594180 timed out during migration/boot of the second iOS 26.5 Simulator. Runs 30395172252 and 30397230869 pinned iOS 26.4 and received loopback GET 200 responses, but the engine remained about:blank and the screenshot content band had zero dark pixels. After three workflow adjustments, the current hosted Simulator gate remains needs-verification.
- Verifier: GitHub run conclusions and downloaded build, native-test, fixture, navigation, system, survival, rendering, and crash logs; screenshot inspection.
