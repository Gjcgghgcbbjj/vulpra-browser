#!/usr/bin/env python3
"""Portable source contracts for the Porcelain Native client presentation."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "App"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def source(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file(), f"missing {relative}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    appearance = source("App/UI/VulpraAppearance.swift")
    for token in (
        "static let porcelain", "static let graphite", "static let accent",
        "static let privateAccent", "static let separator", "static let dockRadius: CGFloat = 12",
        "static let itemRadius: CGFloat = 8",
    ):
        require(token in appearance, f"appearance is missing {token}")
    require("red: 0.05, green: 0.43, blue: 0.92" not in appearance,
            "legacy blue primary accent remains")

    chrome = source("App/UI/BrowserChromeView.swift")
    require("cornerRadius = VulpraAppearance.dockRadius" in chrome, "browser dock does not use 12pt semantic radius")
    require("cornerRadius = VulpraAppearance.itemRadius" in chrome, "address surface does not use 8pt semantic radius")
    require("equalToConstant: 44" in chrome, "browser controls do not preserve 44pt targets")
    require("equalToConstant: 42" in chrome and "equalToConstant: 48" in chrome,
            "address field lacks stable compact/focused heights")
    require("borderWidth" in chrome and "shadowOpacity = 0.07" in chrome,
            "browser dock lacks restrained separation")
    require("buttonRow" in chrome and "UIAccessibility.isReduceMotionEnabled" in chrome,
            "browser focus presentation is not bounded or accessible")

    suggestions = source("App/UI/OmniboxSuggestionsView.swift")
    require("VulpraAppearance.itemRadius" in suggestions, "suggestions do not use the item radius")
    require("rowHeight = 52" in suggestions, "suggestion rows are not compact")

    start = source("App/StartPage/StartPageViewController.swift")
    require("UITextField" not in start and "UITextFieldDelegate" not in start,
            "start page still owns a duplicate search field")
    for token in ("UIScrollView", "VulpraBrandMarkView", "quickGrid", "actionGrid"):
        require(token in start, f"start page is missing {token}")
    require("private var quickURLs" in start, "start page lost quick-site ownership")
    require("actionSymbolConfiguration" in start and "configuration.attributedTitle" in start,
            "start-page commands do not use compact symbol-first presentation")
    require("brandContainer" in start and "brand.centerXAnchor.constraint" in start,
            "compact start-page brand is stretched across the full content width")
    require("font = .systemFont(ofSize: 26" not in start,
            "start-page brand remains visually oversized")

    require("tabCountLabel" in chrome and '"magnifyingglass"' in chrome and
            "let addressSymbol: String" in chrome and
            "lockView.image = UIImage(systemName: state.addressSymbol)" in chrome,
            "browser chrome lacks compact address state and tab-count icon detail")
    require('PressableButton(symbol: "ellipsis.circle"' in chrome and
            "browserChromeDidRequestPageTools" in chrome,
            "page-tools entry does not use truthful icon-first semantics")

    page_tools = source("App/PageTools/PageToolsController.swift")
    for symbol in ("square.and.arrow.up", "star", "desktopcomputer", "textformat.size",
                   "qrcode.viewfinder", "doc.on.doc"):
        require(f'PageToolItem(symbol: "{symbol}"' in page_tools,
                f"page-tools sheet is missing {symbol}")
    require("PageToolsSheetViewController: UITableViewController" in page_tools and
            "sheetPresentationController" in page_tools,
            "page tools do not use the native icon-first sheet")

    privacy_data = source("App/Privacy/PrivacyDataViewController.swift")
    require("content.image = UIImage(systemName:" in privacy_data,
            "privacy data commands are missing semantic symbols")
    for relative in ("App/Library/LibraryViewController.swift", "App/Privacy/SitePermissionsViewController.swift"):
        value = source(relative)
        require('image: UIImage(systemName: "trash")' in value and "accessibilityLabel" in value,
                f"{relative} clear command is not a labeled trash icon")

    brand = source("App/UI/VulpraBrandMarkView.swift")
    require("CAShapeLayer" in brand and "VulpraAppearance.graphite" in brand
            and "VulpraAppearance.accent" in brand, "brand mark does not match the AppIcon geometry/palette")

    tab = source("App/Tabs/TabCardCell.swift")
    require("VulpraAppearance.itemRadius" in tab, "tab card radius is not 8pt")
    require("VulpraAppearance.privateAccent" in tab, "private selected tab lacks teal identity")
    require("borderWidth = selected ? 2 : 1" in tab, "tab selection/border hierarchy is missing")
    overview = source("App/Tabs/TabOverviewViewController.swift")
    require(".systemGroupedBackground" in overview, "tab overview does not use a quiet grouped canvas")
    require("UIBarButtonItem(image: UIImage(systemName:" in overview,
            "tab overview commands still depend on long toolbar text")

    empty = source("App/UI/VulpraEmptyStateView.swift")
    require("final class VulpraEmptyStateView" in empty and "UIImage(systemName:" in empty,
            "missing compact shared empty-state view")
    for relative in (
        "App/Downloads/DownloadsViewController.swift",
        "App/Library/LibraryViewController.swift",
        "App/Privacy/SitePermissionsViewController.swift",
    ):
        require("VulpraEmptyStateView" in source(relative), f"{relative} has no empty state")

    settings = source("App/Settings/SettingsViewController.swift")
    require("private enum Section: Int, CaseIterable" in settings, "settings remain one unstructured section")
    for key in ("settings.section.general", "settings.section.appearance", "settings.section.privacy", "settings.section.data"):
        require(key in settings, f"settings does not expose {key}")

    workflow = source(".github/workflows/simulator-smoke.yml")
    navigation_harness = source("Tools/CI/run-simulator-navigation.sh")
    for token in (
        "r0_attempts:",
        "runtime='com.apple.CoreSimulator.SimRuntime.iOS-26-4'",
        "smoke_url='http://127.0.0.1:8765/'",
        "Tools/CI/run-simulator-navigation.sh",
        "Tools/CI/summarize-r0-engine-gate.py",
        "Tools/CI/check-single-attempt-gate.py",
        "name: r0-engine-gate",
    ):
        require(token in workflow, f"simulator workflow is missing {token}")
    for token in (
        "AppleLanguages -array zh-Hans",
        'SIMCTL_CHILD_VULPRA_SMOKE_URL="$WARM_URL"',
        'openurl "$UDID" "$DEEP_LINK"',
        'simctl create "Vulpra-R0-',
        'simctl install "$UDID" "$APP"',
        'simctl io "$UDID" screenshot "$PREFIX-navigation.png"',
        'simctl shutdown "$UDID"',
        'simctl delete "$UDID"',
    ):
        require(token in navigation_harness, f"Simulator navigation harness is missing {token}")
    # The dark-pixel render audit lives in the shared audit-rendering.sh
    # (commit ae6f094 moved it out of the harness so all three Simulator
    # harnesses reuse the same central-region loop). The harness must invoke
    # the shared audit and the shared audit must contain the audit region.
    require('"$SCRIPT_DIR/audit-rendering.sh" "$PREFIX-navigation.png"' in navigation_harness,
            "Simulator navigation harness does not invoke the shared render audit")
    render_audit = source("Tools/CI/audit-rendering.sh")
    require("for y in (height / 4)..<(height * 3 / 4)" in render_audit,
            "shared render audit is missing the central-region loop")
    require("example.com" not in workflow and "example.com" not in navigation_harness,
            "simulator workflow still depends on mutable external networking")
    # The R0/A2 engine fixture's proven centered dark marker must stay fixed for
    # pixel detection, but the scroll gate fixture deliberately offsets its own
    # marker to top:32vh (pinned by test_scroll_gate_contract.py so the marker
    # lands inside the shared audit region). Scope the layout freeze to the
    # engine fixture so the scroll fixture is not blocked.
    engine_fixture_lines = [
        line for line in workflow.splitlines() if "data-vulpra-engine-fixture" in line
    ]
    require(engine_fixture_lines and all("32vh" not in line for line in engine_fixture_lines),
            "engine fixture still changes proven page layout for pixel detection")
    require(workflow.count("Tools/CI/run-simulator-navigation.sh") == 2,
            "Simulator navigation must invoke the one reusable harness for the single-attempt fast gate and the repeated loop")
    require(navigation_harness.count("AppleLanguages -array zh-Hans") == 1,
            "the reusable Simulator harness must apply the Chinese language preference")

    over = [
        (path.relative_to(ROOT), len(path.read_text(encoding="utf-8").splitlines()))
        for path in APP.rglob("*.swift")
        if len(path.read_text(encoding="utf-8").splitlines()) >= 350
    ]
    require(not over, f"Porcelain UI owner budget exceeded: {over}")
    print("PASS: Porcelain Native client presentation contracts")


if __name__ == "__main__":
    main()
