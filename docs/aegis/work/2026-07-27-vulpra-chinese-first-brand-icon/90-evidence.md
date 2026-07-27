# Vulpra Chinese-First Localization and Brand Icon - Evidence

No evidence has been recorded yet.

## EvidenceBundleDraft

- Artifact key: local-porcelain-portable-gates
- Type: test
- Source: local workspace 2026-07-27
- Summary: All three portable suites, --require-cutover, localization/icon, Porcelain UI, deterministic icon check, compileall, diff check, and Aegis workspace check passed.
- Verifier: ./Tests/IndependentEngine/run-portable.sh; ./Tests/RuntimeShell/run-portable.sh; ./Tests/Browser/run-portable.sh; python3 Tests/IndependentEngine/test_cutover_readiness.py --require-cutover; python3 Tools/Brand/generate-app-icons.py --check

## EvidenceBundleDraft

- Artifact key: final-porcelain-simulator-30219730768
- Type: simulator
- Source: GitHub Actions run 30219730768
- Summary: Xcode build passed; Chinese start page and loaded Example Domain screenshots reviewed; app survived 60 seconds; 40077 rendered dark pixels; all engine events present; no crash report.
- Verifier: gh run view 30219730768; downloaded vulpra-independent-simulator-30219730768 artifact

## EvidenceBundleDraft

- Artifact key: final-ios-packages-30220272887
- Type: package
- Source: GitHub Actions run 30220272887 and local readback
- Summary: IPA and TIPA built and validated; 2671 files; TIPA signatures required; ZIP integrity, localization, AppIcon, bundle identities, engine payload, retired-path absence, and SHA-256 passed.
- Verifier: validate-ipa.py; unzip -tq; sha256sum -c; package resource inspection

## EvidenceBundleDraft

- Artifact key: windows-desktop-delivery
- Type: delivery
- Source: /mnt/c/Users/niting/Desktop/Vulpra
- Summary: Vulpra.ipa, Vulpra-TrollStore.tipa, and SHA256SUMS copied to Windows desktop and matched downloaded artifact hashes.
- Verifier: sha256sum -c /mnt/c/Users/niting/Desktop/Vulpra/SHA256SUMS
