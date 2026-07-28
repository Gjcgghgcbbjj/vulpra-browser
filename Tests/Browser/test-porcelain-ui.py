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
            "lockView.image = UIImage(systemName: symbol)" in chrome,
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
    for token in (
        "simulator-start-page.png",
        "simulator-navigation.png",
        "AppleLanguages -array zh-Hans",
        "simulator_runtime='com.apple.CoreSimulator.SimRuntime.iOS-26-4'",
        "smoke_url='http://127.0.0.1:8765/'",
        'SIMCTL_CHILD_VULPRA_SMOKE_URL="$smoke_url"',
        "for y in (height / 12)..<(height / 8)",
        'curl --max-time 2 --fail --silent --show-error "$smoke_url"',
    ):
        require(token in workflow, f"simulator workflow is missing {token}")
    require("example.com" not in workflow,
            "simulator workflow still depends on mutable external networking")
    require("32vh" not in workflow,
            "simulator fixture still changes proven page layout for pixel detection")
    require(workflow.count("AppleLanguages -array zh-Hans") == 2,
            "both simulator visual states must use the Chinese language preference")
    require(workflow.index("simulator-start-page.png") < workflow.index("SIMCTL_CHILD_VULPRA_SMOKE_URL"),
            "simulator workflow does not capture the start page before URL navigation")
    between_launches = workflow[
        workflow.index("simulator-start-page.png"):workflow.index("SIMCTL_CHILD_VULPRA_SMOKE_URL")
    ]
    require('simctl terminate "$udid" com.vulpra.browser' in between_launches
            and 'simctl shutdown "$udid"' in between_launches
            and 'simctl delete "$udid"' in between_launches
            and 'Vulpra-Navigation-$GITHUB_RUN_ID' in between_launches,
            "simulator workflow does not isolate renderer state between visual states")
    require(workflow.count('simctl install "$udid" "$app"') == 2,
            "both simulator visual states must install the same built app")
    require('run_with_timeout 30 xcrun simctl terminate "$udid" com.vulpra.browser | tee simulator-start-page-terminate.log || true' in workflow,
            "a bounded Simulator terminate timeout still prevents isolated navigation verification")

    over = [
        (path.relative_to(ROOT), len(path.read_text(encoding="utf-8").splitlines()))
        for path in APP.rglob("*.swift")
        if len(path.read_text(encoding="utf-8").splitlines()) >= 350
    ]
    require(not over, f"Porcelain UI owner budget exceeded: {over}")
    print("PASS: Porcelain Native client presentation contracts")


if __name__ == "__main__":
    main()
