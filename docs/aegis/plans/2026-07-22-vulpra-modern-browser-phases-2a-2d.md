# Vulpra Modern Browser Phases 2A-2D Implementation Plan

Goal: Replace the smoke runtime shell with a complete, bounded modern browser client and deterministic GitHub macOS runtime/app build workflows.

Architecture: SceneDelegate owns BrowserViewController; BrowserViewController composes chrome and the selected engine view; TabManager exclusively owns BrowserTab lifecycle; feature-owned Codable stores own settings, bookmarks, history, downloads, permissions, and restoration. GitHub YAML orchestrates existing shell producers rather than duplicating them.

Tech Stack: Swift 5, UIKit, Core Animation, GeckoView, Codable atomic files, POSIX shell, Python portable contract tests, GitHub Actions macOS.

Baseline/Authority Refs: `docs/aegis/specs/2026-07-22-vulpra-modern-browser-product-design.md`, runtime-shell baseline, ADR-0002, efficiency policy.

Compatibility Boundary: iOS 15.0 arm64 iPhone/iPad; four bundle products; exactly-once JIT coordinator; public OpenIn path; no copied Reynard client; no new third-party package dependency.

Verification: portable Python/shell source contracts, plist/project parsing, workflow syntax/contract checks, complexity/dependency scans, macOS GitHub workflow when credentials/remote exist, device gates remain evidence-bound.

## Scope checks

- Requirement Ready Check: ready for Phases 2A-2D; service-backed Phase 3 excluded.
- Architecture Integrity: one owner per tab and feature state; runtime shell deleted when browser root activates.
- Complexity Budget: each maintained product owner below 350 lines; extract views/stores rather than grow a monolith.
- TDD Route: light; portable contract tests precede each source slice because Swift/Xcode is unavailable locally.
- Retirement: remove `RuntimeShellViewController` and its one-session test; do not retain a compatibility wrapper.

## Task 1 - Runtime substrate GitHub workflow
Files: create `.github/workflows/build-runtime-substrate.yml`, `Tests/Browser/test-runtime-workflow.py`; modify `Tools/Runtime/build-runtime-substrate.sh`, `Tests/RuntimeShell/test-runtime-artifacts.sh`, portable runner.
Verification: workflow contract test, shell syntax, portable suite.

## Task 2 - Shared persistence and settings
Files: create `App/Persistence/AtomicJSONStore.swift`, `App/Settings/BrowserSettings.swift`, `App/Settings/SettingsViewController.swift`, tests.
Verification: owner/file contract tests and line budgets.

## Task 3 - Omnibox and tab lifecycle
Files: create `App/Browser/OmniboxResolver.swift`, `BrowserTab.swift`, `TabManager.swift`, tab restoration models, tests.
Verification: URL/search rules, exactly one TabManager, session lifecycle and private persistence exclusions.

## Task 4 - Browser chrome and animation system
Files: create `App/UI/BrowserChromeView.swift`, `App/UI/PressableButton.swift`, `App/UI/BrowserProgressView.swift`, tests.
Verification: native UIKit/Core Animation only, Reduce Motion behavior, address/navigation control contract.

## Task 5 - Browser root and Gecko delegates
Files: create `App/Browser/BrowserViewController.swift`, `BrowserSessionDelegate.swift`; modify SceneDelegate; delete runtime shell.
Verification: selected engine attachment, navigation/progress/title callbacks, lifecycle, share, errors, old-owner absence.

## Task 6 - Tab overview and start page
Files: create `App/Tabs/TabOverviewViewController.swift`, `TabCardCell.swift`, `App/StartPage/StartPageViewController.swift`, tests.
Verification: create/select/close/undo, private thumbnail exclusion, local-only start page.

## Task 7 - Bookmarks, history, and recently closed
Files: create feature models/stores and list controllers under `App/Library/`, tests.
Verification: atomic bounded persistence, private exclusion, add/search/delete behavior contracts.

## Task 8 - Page tools and private browsing
Files: create `App/PageTools/PageToolsController.swift`; connect find, desktop mode, zoom, share/copy, private tab entry and snapshot privacy.
Verification: explicit supported operations, no fake reader/translation providers.

## Task 9 - Downloads
Files: create `App/Downloads/DownloadManager.swift`, models and controller; connect Gecko external response callbacks.
Verification: streamed file ownership, bounded metadata, cancel/failure/cleanup contracts.

## Task 10 - Privacy, permissions, and extensions
Files: create `App/Privacy/SitePermissionStore.swift`, `BrowserPermissionController.swift`, privacy settings UI, `App/Addons/AddonManagementViewController.swift`; adjust Gecko session settings for tracking protection.
Verification: private isolation, per-site decisions, standard/strict/custom policy, existing AddonRuntime ownership only.

## Task 11 - IPA/TIPA GitHub workflow
Files: create `.github/workflows/build-ios-packages.yml`, workflow tests, runtime artifact restore helper if necessary.
Verification: exact artifact identity, no Gecko rebuild, Xcode archive/package commands, checksums and uploaded products.

## Task 12 - Portable integration and complexity closeout
Files: create `Tests/Browser/run-portable.sh` and focused tests; update RuntimeShell runner, README, baseline/ADR.
Verification: all portable suites, syntax/plist/project checks, no dependencies/binaries, per-owner line budgets, `git diff --check`, clean status after commit.

## Mac/device evidence boundary

GitHub execution requires a valid token and remote. Physical iOS 15.8/16.7 installation, JIT, performance, animation, and package verification cannot be claimed from Linux. Workflows and exact commands will be complete; external execution remains blocked until credentials and runner/device access exist.
