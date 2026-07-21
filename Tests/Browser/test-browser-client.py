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
        'App/Browser/TabManager.swift': ('final class TabManager', 'suspendBackgroundTabs', 'closePrivateTabs'),
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
    require('<key>NSCameraUsageDescription</key>' in text('App/Info.plist'), 'QR camera usage description missing')

    owners = list(APP.rglob('*.swift'))
    over = [(p.relative_to(ROOT), len(p.read_text().splitlines())) for p in owners if len(p.read_text().splitlines()) >= 350]
    require(not over, f'product owner line budget exceeded: {over}')
    require(len(list(APP.rglob('*.swift'))) >= 20, 'browser feature modules are incomplete')
    print(f'PASS: modern browser client contracts ({len(owners)} Swift files)')
if __name__ == '__main__': main()
