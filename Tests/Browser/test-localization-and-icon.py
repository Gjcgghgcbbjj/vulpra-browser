#!/usr/bin/env python3
"""Portable contracts for Chinese-first localization and the Vulpra AppIcon."""

import json
import re
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "App"
OPEN_IN = ROOT / "Extensions/OpenIn"
STRING_LINE = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";\s*$')


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def parse_strings(path: Path) -> dict[str, str]:
    require(path.is_file(), f"missing localization file: {path.relative_to(ROOT)}")
    values: dict[str, str] = {}
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("/*"):
            continue
        match = STRING_LINE.fullmatch(line)
        require(match is not None, f"invalid .strings line {path.relative_to(ROOT)}:{number}")
        key, value = (json.loads(f'"{part}"') for part in match.groups())
        require(key not in values, f"duplicate localization key {key!r} in {path.relative_to(ROOT)}")
        values[key] = value
    require(values, f"empty localization file: {path.relative_to(ROOT)}")
    return values


def png_pixels(path: Path) -> tuple[int, int, list[tuple[int, int, int]]]:
    data = path.read_bytes()
    require(data.startswith(b"\x89PNG\r\n\x1a\n"), f"invalid PNG signature: {path.name}")
    offset = 8
    width = height = color_type = -1
    compressed = bytearray()
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            require((depth, color_type, compression, filtering, interlace) == (8, 2, 0, 0, 0),
                    f"AppIcon must be opaque 8-bit RGB without interlace: {path.name}")
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
        offset += 12 + length
    require(width > 0 and height > 0 and compressed, f"incomplete PNG: {path.name}")
    raw = zlib.decompress(compressed)
    stride = width * 3
    require(len(raw) == height * (stride + 1), f"unexpected PNG payload: {path.name}")
    pixels: list[tuple[int, int, int]] = []
    for row in range(height):
        start = row * (stride + 1)
        require(raw[start] == 0, f"AppIcon generator must emit deterministic unfiltered rows: {path.name}")
        scanline = raw[start + 1 : start + stride + 1]
        pixels.extend(zip(scanline[0::3], scanline[1::3], scanline[2::3]))
    return width, height, pixels


def main() -> None:
    app_zh = parse_strings(APP / "zh-Hans.lproj/Localizable.strings")
    app_en = parse_strings(APP / "en.lproj/Localizable.strings")
    open_zh = parse_strings(OPEN_IN / "zh-Hans.lproj/Localizable.strings")
    open_en = parse_strings(OPEN_IN / "en.lproj/Localizable.strings")
    require(app_zh.keys() == app_en.keys(), "App Chinese and English localization keys differ")
    require(open_zh.keys() == open_en.keys(), "OpenIn Chinese and English localization keys differ")

    required = {
        "common.cancel", "common.ok", "browser.search.placeholder", "browser.back",
        "browser.tabs.count", "start.bookmarks", "tab.new", "tab.private",
        "library.clear_history", "downloads.title", "page_tools.title",
        "permission.allow", "privacy.clear_data", "settings.title",
        "settings.history_days",
    }
    require(required <= app_zh.keys(), f"missing required App localization keys: {sorted(required - app_zh.keys())}")
    for key in required - {"browser.tabs.count", "settings.history_days"}:
        require(any(ord(character) > 127 for character in app_zh[key]), f"Chinese value is not localized: {key}")
    require("%" in app_zh["browser.tabs.count"], "tab-count localization must remain formatted")
    require("%" in app_zh["settings.history_days"], "history-day localization must remain formatted")

    app_info_zh = parse_strings(APP / "zh-Hans.lproj/InfoPlist.strings")
    app_info_en = parse_strings(APP / "en.lproj/InfoPlist.strings")
    require(app_info_zh.keys() == app_info_en.keys(), "App InfoPlist localization keys differ")
    require({"CFBundleDisplayName", "NSCameraUsageDescription", "NSPhotoLibraryAddUsageDescription"} <= app_info_zh.keys(),
            "App InfoPlist localization is incomplete")
    require(any(ord(character) > 127 for character in app_info_zh["NSCameraUsageDescription"]),
            "camera permission description is not Chinese")
    open_info_zh = parse_strings(OPEN_IN / "zh-Hans.lproj/InfoPlist.strings")
    open_info_en = parse_strings(OPEN_IN / "en.lproj/InfoPlist.strings")
    require(open_info_zh.keys() == open_info_en.keys() == {"CFBundleDisplayName"},
            "OpenIn display-name localization is incomplete")

    base = (ROOT / "Configuration/Base.xcconfig").read_text(encoding="utf-8")
    identity_config = (ROOT / "Configuration/BuildIdentity.generated.xcconfig").read_text(encoding="utf-8")
    project = (ROOT / "Vulpra.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    app_config = (ROOT / "Configuration/App.xcconfig").read_text(encoding="utf-8")
    require('#include "BuildIdentity.generated.xcconfig"' in base and
            "DEVELOPMENT_LANGUAGE = zh-Hans" in identity_config,
            "zh-Hans is not the default development language")
    require("developmentRegion = zh-Hans" in project, "Xcode developmentRegion is not zh-Hans")
    require("knownRegions = (zh-Hans, en, Base, )" in project, "Xcode knownRegions do not include Chinese first")
    require("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon" in app_config, "AppIcon is not configured for the App target")

    app_sources = {
        path.relative_to(APP).as_posix(): path.read_text(encoding="utf-8")
        for path in APP.rglob("*.swift")
    }
    app_source = "\n".join(app_sources.values())
    require("enum VulpraL10n" in app_source, "missing VulpraL10n helper")
    require("VulpraL10n." in app_source, "App display text does not use VulpraL10n")
    forbidden_display_literals = {
        "Search or enter website", "Bookmarks", "History", "Downloads", "Private", "Settings",
        "Back", "Forward", "Reload", "Share", "Tabs", "Stop", "New Tab", "Private tab",
        "Clear History", "Page Tools", "Scan QR Code", "Camera unavailable", "Don't Allow",
        "Clear Browsing Data", "Site Permissions", "Undo Close", "Close Others",
    }
    technical_exemptions = {
        ("Browser/BrowserTab.swift", "New Tab"),
        ("Downloads/DownloadManager.swift", "Downloads"),
    }
    lingering = sorted(
        f"{path}: {value}"
        for path, source in app_sources.items()
        for value in forbidden_display_literals
        if f'"{value}"' in source and (path, value) not in technical_exemptions
    )
    require(not lingering, f"hard-coded user-visible English remains: {lingering}")
    open_source = (OPEN_IN / "OpenInViewController.swift").read_text(encoding="utf-8")
    require("NSLocalizedString" in open_source, "OpenIn errors are not localized")

    catalog = APP / "Resources/Assets.xcassets/AppIcon.appiconset"
    manifest_path = catalog / "Contents.json"
    require(manifest_path.is_file(), "missing AppIcon asset manifest")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    images = manifest.get("images")
    require(isinstance(images, list) and len(images) == 18, "AppIcon must contain 18 iOS 15 renditions")
    require(sum(image.get("idiom") == "ios-marketing" for image in images) == 1,
            "AppIcon must contain exactly one marketing rendition")
    seen: set[tuple[str, str, str]] = set()
    for image in images:
        key = (image.get("idiom", ""), image.get("size", ""), image.get("scale", ""))
        require(key not in seen, f"duplicate AppIcon role: {key}")
        seen.add(key)
        filename = image.get("filename")
        require(isinstance(filename, str) and filename.endswith(".png"), f"AppIcon role has no PNG: {key}")
        size = float(image["size"].split("x", 1)[0])
        scale = int(image["scale"].removesuffix("x"))
        expected = round(size * scale)
        width, height, pixels = png_pixels(catalog / filename)
        require((width, height) == (expected, expected),
                f"wrong AppIcon dimensions for {filename}: {(width, height)} != {(expected, expected)}")
        porcelain = sum(red >= 235 and green >= 235 and blue >= 232 for red, green, blue in pixels)
        require(porcelain / len(pixels) >= 0.58, f"AppIcon is not predominantly white: {filename}")

    print(f"PASS: Chinese-first localization and White Porcelain AppIcon ({len(app_zh)} App keys)")


if __name__ == "__main__":
    main()
