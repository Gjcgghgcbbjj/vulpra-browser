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
