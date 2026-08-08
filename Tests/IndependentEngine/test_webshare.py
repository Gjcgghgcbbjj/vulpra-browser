#!/usr/bin/env python3
"""Draft: WebShare (navigator.share) G8 fix contract.

Prepared during gate 31244916221 wait (read-only; NOT yet committed).
When the lifecycle gate goes green, this becomes
Tests/IndependentEngine/test_webshare.py together with the
EngineFeatures.swift + VulpraEngineSession.swift + BrowserPromptController.swift
share fix (see .build/webshare-fix.patch).

Usage: python3 test_webshare_draft.py [ROOT_OVERRIDE]
ROOT_OVERRIDE = path to a patched copy of the worktree (PASS expected).
Default = this worktree (FAIL expected on current HEAD).
"""
import pathlib
import re
import sys
from pathlib import Path


def find_root() -> Path:
    p = Path(__file__).resolve().parent
    for _ in range(6):
        if (p / "Engine" / "VulpraEngineKit" / "Public" / "EngineFeatures.swift").is_file():
            return p
        if p.parent == p:
            break
        p = p.parent
    raise SystemExit("FAIL: cannot locate worktree root from " + str(Path(__file__).resolve().parent))


ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else find_root()
FEATURES = ROOT / "Engine/VulpraEngineKit/Public/EngineFeatures.swift"
SESSION = ROOT / "Engine/VulpraEngineKit/Internal/Session/VulpraEngineSession.swift"
PROMPT_CTRL = ROOT / "App/Browser/BrowserPromptController.swift"
OMNIJAR = ROOT / ".build/omnijar-verify-root/runtime/resources/omni.ja"


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise SystemExit(f"FAIL: {msg}")


def read(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"FAIL: missing {path}")
    return path.read_text(encoding="utf-8")


def main() -> int:
    features = read(FEATURES)
    session = read(SESSION)
    prompt = read(PROMPT_CTRL)
    import zipfile
    with zipfile.ZipFile(OMNIJAR) as z:
        share = z.read("modules/ShareDelegate.sys.mjs").decode("utf-8", errors="ignore")

    # 1. Gecko side: navigator.share -> ShareDelegate -> GeckoViewPrompter with
    #    type "share"; resolves via result.response with 0=success/1=failure/2=abort.
    require('type: "share"' in share,
            "ShareDelegate.sys.mjs lost the share prompt type")
    require("result.response" in share,
            "ShareDelegate.sys.mjs no longer reads result.response")
    for resp, label in [("case SUCCESS:", "success"), ("case FAILURE:", "failure"), ("case ABORT:", "abort")]:
        require(resp in share, f"ShareDelegate.sys.mjs lost {label} response branch")

    # 2. EnginePromptKind must expose a dedicated .share case.
    require("case alert, confirm, text, authentication, file, share, unknown" in features
            or re.search(r"case\s+share", features),
            "EnginePromptKind has no .share case")

    # 3. EnginePromptRequest must carry share payload (text + uri).
    require("public let text: String?" in features and "public let uri: URL?" in features,
            "EnginePromptRequest is missing share text/uri fields")

    # 4. Engine session must map type "share" -> .share kind.
    require('type == "share" ? .share' in session,
            "VulpraEngineSession does not map share prompt type")

    # 5. Engine session must resolve share prompts with Gecko contract
    #    {"response": 0|1|2}, not the generic {"allow","text","files"}.
    require('"response": NSNumber(value: response?.accepted ?? false ? 0 : 2)' in session,
            "share prompt is not resolved with response 0/2")

    # 6. App must present a real share sheet (UIActivityViewController) and map
    #    completion -> accepted, dismissal -> abort.
    require('prompt.kind == .share' in prompt,
            "BrowserPromptController has no .share branch")
    require("UIActivityViewController" in prompt,
            "BrowserPromptController does not present UIActivityViewController for share")
    require("completionWithItemsHandler" in prompt,
            "share sheet completion is not wired")
    require("presentationControllerDidDismiss" in prompt,
            "share sheet dismissal (abort) is not wired")

    print(f"PASS: WebShare G8 fix contract verified at {ROOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
