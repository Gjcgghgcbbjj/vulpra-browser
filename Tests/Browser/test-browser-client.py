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

    addon_runtime = text('Extensions/GeckoView/Addons/AddonRuntime.swift')
    delegate_setter = addon_runtime.split('public weak var delegate', 1)[1].split('var addonsByID', 1)[0]
    require('Task {' not in delegate_setter and 'self.list()' not in delegate_setter,
            'addon delegate assignment queries Gecko before its JS runtime is ready')
    require('notifyActionDelegateAttached()' in delegate_setter,
            'addon delegate reassignment no longer restores cached action delegates')
    require('AddonRuntime.shared.list()' in text('App/Addons/AddonManagementViewController.swift'),
            'addon management no longer performs an explicit post-startup refresh')

    tab = text('App/Browser/BrowserTab.swift')
    require('activate(settings: settings).load' not in tab, 'new tabs perform a duplicate first navigation')
    require('if let session {' in tab and 'session.load(target.absoluteString)' in tab,
            'tab load path does not distinguish live and restored sessions')

    manager = text('App/Browser/TabManager.swift')
    for token in ('pendingMetadataPersistence', 'persistImmediately: false',
                  'DispatchQueue.main.asyncAfter', 'maximumRestoredTabs',
                  'maximumLiveBackgroundSessions', 'enforceSessionBudget'):
        require(token in manager, f'tab lifecycle efficiency contract missing: {token}')

    browser = text('App/Browser/BrowserViewController.swift')
    require('tab.progress == 100' in browser, 'history can be recorded before a successful page stop')
    require('recordedURLs = recordedURLs.filter' in browser, 'closed-tab history bookkeeping is unbounded')
    require('guard attachedEngineView !== engineView else { return }' in browser,
            'metadata updates can repeatedly detach and reattach the same Gecko view')
    require('releaseMemoryPressure()' in browser,
            'browser memory warnings do not invoke the bounded tab cleanup owner')

    require('progress = success ? 100 : 0' in tab,
            'failed page loads can retain a successful progress marker and enter history')
    require('discardThumbnail()' in tab and 'markAccessed()' in tab,
            'tab metadata lacks bounded thumbnail or LRU lifecycle hooks')
    for token in ('maximumCachedThumbnails', 'enforceThumbnailBudget', 'releaseMemoryPressure'):
        require(token in manager, f'tab memory-pressure contract missing: {token}')

    downloads = text('App/Downloads/DownloadManager.swift')
    require('lastProgressPersistence' in downloads and 'timeIntervalSince(lastProgressPersistence) >= 1' in downloads,
            'download progress persistence is not throttled')

    context_menu = text('App/PageTools/BrowserContextMenuController.swift')
    require('downloadTask(with:' in context_menu, 'image saving still buffers the full network response')
    require('dataTask(with:' not in context_menu and 'UIImage(data:' not in context_menu,
            'image saving retains the old in-memory payload path')
    require('FileManager.default.temporaryDirectory' in context_menu and 'performChanges' in context_menu,
            'photo saving relies on the URLSession callback-only temporary file lifetime')

    progress_view = text('App/UI/BrowserProgressView.swift')
    require('guard finished else { return }' in progress_view,
            'an interrupted completion fade can hide a newer page load')

    require('popoverPresentationController?.sourceView = view' in text('App/Settings/SettingsViewController.swift'),
            'settings action sheets can crash on iPad')
    require('popoverPresentationController?.sourceView = view' in text('App/Library/LibraryViewController.swift'),
            'history action sheet can crash on iPad')
    require('as! TabCardCell' not in text('App/Tabs/TabOverviewViewController.swift'),
            'tab grid retains a forced cell cast')
    require('func url(for query: String) -> URL?' in text('App/Settings/BrowserSettings.swift'),
            'search URL construction retains a forced fallback unwrap')
    require('prefix(5_000)' in text('App/Library/BrowserLibrary.swift'), 'bookmark storage is not bounded')
    require('prefix(1_000)' in text('App/Privacy/SitePermissionStore.swift'), 'site permission storage is not bounded')

    owners = list(APP.rglob('*.swift'))
    over = [(p.relative_to(ROOT), len(p.read_text().splitlines())) for p in owners if len(p.read_text().splitlines()) >= 350]
    require(not over, f'product owner line budget exceeded: {over}')
    require(len(list(APP.rglob('*.swift'))) >= 20, 'browser feature modules are incomplete')
    print(f'PASS: modern browser client contracts ({len(owners)} Swift files)')
if __name__ == '__main__': main()
