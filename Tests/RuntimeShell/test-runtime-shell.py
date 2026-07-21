#!/usr/bin/env python3
"""Portable source-contract checks for the one-session UIKit runtime shell."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "App"
GECKO_SESSION = ROOT / "Extensions" / "GeckoView" / "Session" / "GeckoSession.swift"


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def source(name: str) -> str:
    path = APP / name
    require(path.is_file(), f"missing App/{name}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    if not (APP / "main.swift").is_file():
        fail("missing App/main.swift")

    require(not (APP / "AppDelegate.swift").exists(), "unused second application delegate is forbidden")
    entry = source("main.swift")
    scene = source("SceneDelegate.swift")
    shell = source("RuntimeShellViewController.swift")
    require(GECKO_SESSION.is_file(), "missing canonical GeckoSession source")
    gecko_session = GECKO_SESSION.read_text(encoding="utf-8")

    for imported in ("Foundation", "UIKit", "GeckoView"):
        require(f"import {imported}" in entry, f"main.swift must import {imported}")
    jit_start = entry.find("RuntimeJITCoordinator.shared.start()")
    gecko_main = entry.find("GeckoRuntime.main")
    require(jit_start >= 0, "main.swift must start JIT orchestration")
    require(gecko_main > jit_start, "JIT orchestration must start before GeckoRuntime.main")
    require("CommandLine.argc" in entry and "CommandLine.unsafeArgv" in entry, "main.swift must forward process arguments")

    require("final class SceneDelegate: UIResponder, UIWindowSceneDelegate" in scene, "wrong SceneDelegate declaration")
    require(scene.count("var window: UIWindow?") == 1, "SceneDelegate must own one window")
    for token in (
        "RuntimeShellViewController(",
        "window.rootViewController = runtimeShell",
        "window.makeKeyAndVisible()",
        "RuntimeURLRouter.resolve(",
        "func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>)",
        "runtimeShell.open(url)",
        "sceneDidBecomeActive",
        "sceneWillResignActive",
        "sceneDidEnterBackground",
    ):
        require(token in scene, f"SceneDelegate missing contract: {token}")
    require(scene.count("RuntimeShellViewController(") == 1, "SceneDelegate must create one runtime shell")

    require("final class RuntimeShellViewController: UIViewController" in shell, "wrong runtime shell declaration")
    require(shell.count("GeckoSession(") == 1, "runtime shell must own one GeckoSession")
    require(shell.count("session.open(") == 1, "GeckoSession must open exactly once")
    require(shell.count("session.close(") == 1, "GeckoSession must close exactly once")
    require("session.engineView" in shell, "runtime shell must embed engineView")
    require("translatesAutoresizingMaskIntoConstraints = false" in shell, "engineView must use Auto Layout")
    for anchor in ("topAnchor", "leadingAnchor", "bottomAnchor", "trailingAnchor"):
        require(anchor in shell, f"engineView constraint missing: {anchor}")
    require('"https://example.com/"' in shell, "deterministic smoke URL is missing")
    require("session.load(url.absoluteString)" in shell, "runtime shell must load the selected URL")
    require("session.setActive(active)" in shell, "runtime shell must update active state")
    require("session.setFocused(active)" in shell, "runtime shell must update focused state")
    require("UILabel()" in shell and "engine view unavailable" in shell.lower(), "missing plain engine failure label")
    require(
        'fatalError("GeckoView window has no view")' not in gecko_session,
        "GeckoSession still terminates before the App owner can handle a missing engine view",
    )
    require(
        "if let engineView = window?.view()" in gecko_session,
        "GeckoSession must conditionally attach autofill to an available engine view",
    )

    combined = "\n".join((entry, scene, shell))
    forbidden = (
        "tabs",
        "stores",
        "preferences",
        "migration",
        "address bar",
        "bookmarks",
        "downloads",
        "WKWebView",
        "WebKit",
        "UserDefaults",
    )
    for token in forbidden:
        require(re.search(rf"\b{re.escape(token)}\b", combined, re.I) is None, f"runtime shell contains forbidden owner: {token}")

    for name in ("main.swift", "SceneDelegate.swift", "RuntimeShellViewController.swift"):
        lines = len(source(name).splitlines())
        require(lines < 250, f"App/{name} has {lines} lines; runtime owner budget is < 250")

    print("PASS: minimal one-session Gecko runtime shell")


if __name__ == "__main__":
    main()
