#!/usr/bin/env python3
"""Portable contracts for deterministic input and recoverable navigation failures."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def source(relative: str) -> str:
    path = ROOT / relative
    require(path.is_file(), f"missing {relative}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    resolver = source("App/Browser/OmniboxResolver.swift")
    for token in (
        "struct OmniboxResolution", "httpFallbackURL", "isLocalHost",
        "URLComponents", "explicitScheme",
    ):
        require(token in resolver, f"omnibox resolver is missing {token}")
    require("value.contains(\".\")" not in resolver,
            "host recognition still relies on the dot-only heuristic")

    settings = source("App/Settings/BrowserSettings.swift")
    require("URLQueryItem(name: \"q\", value: query)" in settings,
            "search queries are not encoded as a structured query item")
    require("addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)" not in settings,
            "search queries still allow URL query delimiters through")

    session = source("Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift")
    require('case "GeckoView:OnLoadError"' in session,
            "engine session still drops typed Gecko navigation failures")
    require('code: "navigation-failed"' in session and 'payload["uri"]' in session,
            "load errors do not preserve the failed URL and typed failure code")
    require("navigationFailureReported" in session and "!navigationFailureReported" in session,
            "load-error and failed page-stop events are not coalesced")

    message_contract = source("Configuration/engine-message-contract.json")
    require('"GeckoView:OnLoadError"' in message_contract and
            all(f'"{field}"' in message_contract for field in ("uri", "error", "errorModule", "errorClass")),
            "engine message contract omits the Gecko load-error payload")

    tab = source("App/Browser/BrowserTab.swift")
    require("httpFallbackURL" in tab and "func loadHTTPFallback" in tab,
            "browser tab does not own explicit HTTPS-upgrade recovery state")
    require("case .failed(_, let failure)" in tab,
            "browser tab does not consume typed engine navigation failures")

    controller = source("App/Browser/BrowserViewController.swift")
    require("OmniboxResolver.resolve" in controller and ".httpFallbackURL" in controller,
            "browser controller does not carry typed omnibox resolution")
    require('VulpraL10n.text("browser.use_http")' in controller,
            "navigation failure UI has no explicit HTTP recovery action")

    for relative in ("App/en.lproj/Localizable.strings", "App/zh-Hans.lproj/Localizable.strings"):
        localization = source(relative)
        for key in ("browser.load_failure", "browser.use_http"):
            require(f'"{key}"' in localization, f"{relative} is missing {key}")

    print("PASS: deterministic browser input and navigation recovery contracts")


if __name__ == "__main__":
    main()
