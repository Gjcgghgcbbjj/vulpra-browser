#!/usr/bin/env python3
"""Verify the one-path OpenIn share-extension contract."""

from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INFO = ROOT / "Extensions" / "OpenIn" / "Info.plist"
SOURCE = ROOT / "Extensions" / "OpenIn" / "OpenInViewController.swift"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def main() -> None:
    if not SOURCE.is_file():
        fail("missing Extensions/OpenIn/OpenInViewController.swift")
    require(INFO.is_file(), "missing Extensions/OpenIn/Info.plist")

    with INFO.open("rb") as handle:
        info = plistlib.load(handle)
    extension = info.get("NSExtension", {})
    require(extension.get("NSExtensionPointIdentifier") == "com.apple.share-services", "wrong extension point")
    require(
        extension.get("NSExtensionPrincipalClass") == "$(PRODUCT_MODULE_NAME).VulpraOpenInViewController",
        "wrong Vulpra OpenIn principal class",
    )
    activation = extension.get("NSExtensionAttributes", {}).get("NSExtensionActivationRule")
    require(
        activation == {"NSExtensionActivationSupportsWebURLWithMaxCount": 1},
        "OpenIn must accept exactly one web URL",
    )

    source = SOURCE.read_text(encoding="utf-8")
    require(len(source.splitlines()) < 250, "OpenInViewController exceeds 250-line budget")
    require("import UniformTypeIdentifiers" in source, "OpenIn must use UniformTypeIdentifiers")
    require("@MainActor" in source, "completion state must be main-actor isolated")
    require("final class VulpraOpenInViewController: UIViewController" in source, "wrong OpenIn class")
    require("private var didFinish = false" in source, "missing completion gate")
    require("guard !didFinish else" in source and "didFinish = true" in source, "completion gate is incomplete")
    require("UTType.url.identifier" in source, "URL provider type is missing")
    require("hasItemConformingToTypeIdentifier" in source, "URL provider selection is missing")
    require("loadItem(forTypeIdentifier:" in source, "URL extraction is missing")
    require('components.scheme = "vulpra"' in source, "custom scheme is missing")
    require('components.host = "open"' in source, "custom host is missing")
    require('URLQueryItem(name: "url", value: sharedURL.absoluteString)' in source, "shared URL is not encoded as a query item")
    require(source.count("extensionContext.open(") == 1, "expected exactly one NSExtensionContext.open path")
    require(source.count("completeRequest(") == 1, "expected one completion call")
    require(source.count("cancelRequest(") == 1, "expected one cancellation call")
    require('domain: "Vulpra.OpenIn"' in source, "wrong OpenIn error identity")

    for forbidden in (
        "LSApplicationWorkspace",
        "openURL:",
        "UIApplication.shared",
        "nextResponder",
        "performSelector",
        "Reynard",
    ):
        require(forbidden not in source, f"forbidden OpenIn path remains: {forbidden}")

    opening_functions = re.findall(r"func\s+([A-Za-z0-9_]*open[A-Za-z0-9_]*)\s*\(", source, re.I)
    require(opening_functions == ["openSharedURL"], f"unexpected opening functions: {opening_functions}")

    print("PASS: one-path Vulpra OpenIn extension")


if __name__ == "__main__":
    main()
