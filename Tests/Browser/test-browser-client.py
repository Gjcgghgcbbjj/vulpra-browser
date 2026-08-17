#!/usr/bin/env python3
"""Portable source/ownership contracts for Vulpra's modern browser client."""
from pathlib import Path
import re
import sys
ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'App'

def require(ok, message):
    if not ok:
        print('FAIL:', message, file=sys.stderr); raise SystemExit(1)

def text(path):
    p = ROOT / path; require(p.is_file(), f'missing {path}'); return p.read_text()

def main():
    require(not (APP / 'RuntimeShellViewController.swift').exists(), 'smoke runtime shell was not retired')
    scene = text('App/SceneDelegate.swift')
    require('BrowserViewController(initialURL:' in scene, 'SceneDelegate does not create browser root')
    require('RuntimeShellViewController' not in scene, 'SceneDelegate retains old shell owner')

    required = {
        'App/Browser/BrowserViewController.swift': ('final class BrowserViewController', 'BrowserChromeViewDelegate', 'TabManagerDelegate'),
        'App/Browser/TabManager.swift': ('final class TabManager', 'suspendBackgroundTabs', 'closePrivateTabs', 'removeAll(where: \\.isPrivate)'),
        'App/Browser/BrowserTab.swift': ('final class BrowserTab', 'GeckoSession', 'isPrivate'),
        'App/UI/BrowserChromeView.swift': ('UIVisualEffectView', 'UIView.animate', 'UIAccessibility.isReduceMotionEnabled'),
        'App/Tabs/TabOverviewViewController.swift': ('UICollectionView', 'privateControl', 'newTab'),
        'App/StartPage/StartPageViewController.swift': ('Bookmarks', 'History', 'Downloads', 'Private'),
        'App/Library/BrowserLibrary.swift': ('BookmarkStore', 'HistoryStore', 'privateMode'),
        'App/Downloads/DownloadManager.swift': ('DownloadManager', 'moveItem', 'receivedBytes'),
        'App/Privacy/BrowserPermissionController.swift': ('PermissionEmbedderDelegate', 'SitePermissionStore'),
        'App/Addons/AddonManagementViewController.swift': ('AddonRuntime.shared', 'UIDocumentPicker'),
        'App/Settings/BrowserSettings.swift': ('TrackingProtectionLevel', 'httpsOnly', 'SearchEngine'),
        'App/PageTools/PageToolsController.swift': ('Find in Page', 'Request Desktop Site', 'Page Zoom'),
        'App/PageTools/BrowserPictureInPictureController.swift': ('AVPictureInPictureSampleBufferPlaybackDelegate', 'completion: @escaping'),
        'App/PageTools/QRScannerViewController.swift': ('AVCaptureSession', 'metadataObjectTypes = [.qr]'),
        'App/Persistence/AtomicJSONStore.swift': ('JSONEncoder', 'replaceItemAt', 'DispatchQueue'),
    }
    for path, tokens in required.items():
        source = text(path)
        for token in tokens: require(token in source, f'{path} missing {token}')

    combined = '\n'.join(p.read_text() for p in APP.rglob('*.swift'))
    for forbidden in ('WKWebView', 'import WebKit', 'Lottie', 'Firebase', 'GoogleMobileAds'):
        require(forbidden not in combined, f'forbidden dependency/path: {forbidden}')
    require('privateTabs never persist' not in combined, 'placeholder prose leaked into source')
    require('trackingProtection: trackingProtection != .standard' in text('App/Settings/BrowserSettings.swift'),
            'tracking protection is not connected to Gecko settings')
    info = text('App/Info.plist')
    require('<key>NSCameraUsageDescription</key>' in info, 'QR camera usage description missing')
    require('<key>CADisableMinimumFrameDurationOnPhone</key>' in info and '<true/>' in info, '120 Hz opt-in missing')
    require('VulpraAppearance.applyGlobal()' in scene, 'global appearance is not installed')

    # Loading and scrolling stay responsive only when transient Gecko events do
    # not enter the tab-persistence / engine-view attachment path.
    browser_tab = text('App/Browser/BrowserTab.swift')
    tab_manager = text('App/Browser/TabManager.swift')
    browser_root = text('App/Browser/BrowserViewController.swift')
    for token in (
        'browserTabPresentationDidChange',
        'browserTabPersistableStateDidChange',
        'browserTabSessionDidChange',
        'pendingLoadURL',
        'flushPendingLoadIfPossible',
    ):
        require(token in browser_tab, f'BrowserTab performance contract missing {token}')
    require(
        len(re.findall(r'\b(?:created|session)\.load\(', browser_tab)) == 1,
        'BrowserTab has more than one engine load path for a submitted URL',
    )
    progress_handler = re.search(
        r'func onProgressChange\([^}]+\}', browser_tab, flags=re.DOTALL
    )
    require(progress_handler is not None, 'BrowserTab progress handler missing')
    require(
        'browserTabPresentationDidChange' in progress_handler.group(0)
        and 'browserTabPersistableStateDidChange' not in progress_handler.group(0),
        'progress events still enter tab persistence',
    )
    require(
        'func browserTabPresentationDidChange' in tab_manager
        and 'func browserTabPersistableStateDidChange' in tab_manager,
        'TabManager does not separate transient and persisted tab state',
    )
    require(
        'guard attachedEngineView !== engineView else' in browser_root,
        'selected Gecko engine view is reattached for presentation-only updates',
    )
    suggestions = text('App/Browser/OmniboxSuggestions.swift')
    library = text('App/Library/BrowserLibrary.swift')
    require(
        'BookmarkStore.shared.matches(value, limit: 6)' in suggestions
        and 'HistoryStore.shared.matches(value, limit: 8)' in suggestions,
        'omnibox suggestions still materialize unbounded library searches',
    )
    require(
        library.count('func matches(_ query: String, limit: Int)') == 2,
        'bounded bookmark/history suggestion queries are missing',
    )
    chrome = text('App/UI/BrowserChromeView.swift')
    require(
        'private struct RenderState: Equatable' in chrome
        and 'guard state != renderedState else { return }' in chrome,
        'browser chrome still redraws every field for duplicate Gecko progress state',
    )
    require(
        'addressField.text = renderedState?.address' in chrome,
        'address field does not reconcile deferred URL state when editing ends',
    )

    owners = list(APP.rglob('*.swift'))
    over = [(p.relative_to(ROOT), len(p.read_text().splitlines())) for p in owners if len(p.read_text().splitlines()) >= 350]
    require(not over, f'product owner line budget exceeded: {over}')
    require(len(list(APP.rglob('*.swift'))) >= 20, 'browser feature modules are incomplete')
    print(f'PASS: modern browser client contracts ({len(owners)} Swift files)')
if __name__ == '__main__': main()
