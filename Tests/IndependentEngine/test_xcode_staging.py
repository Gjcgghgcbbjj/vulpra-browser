#!/usr/bin/env python3
from pathlib import Path
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "Vulpra.xcodeproj/project.pbxproj"
SCHEME = ROOT / "Vulpra.xcodeproj/xcshareddata/xcschemes/Vulpra.xcscheme"
SIMULATOR_WORKFLOW = ROOT / ".github/workflows/simulator-smoke.yml"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> None:
    text = PROJECT.read_text(encoding="utf-8")
    for token in (
        "VulpraEngineKit.framework in Frameworks",
        "VulpraEngineKit.framework in Embed Frameworks",
        "Vulpra Engine Process.appex in Embed App Extensions",
        "name = VulpraEngineKit; target = AB0000000000000000000005",
        'name = "Vulpra Engine Process"; target = AB0000000000000000000006',
        "Stage Engine Runtime",
        "Relocate Simulator Kernel Link",
        "Verify Engine Artifact",
    ):
        require(token in text, f"independent graph is missing: {token}")
    for token in (
        "GeckoView.framework", "Vulpra Helper", "Extensions/GeckoView",
        "Extensions/Helper", "Modules/VulpraRuntime", "Vendor/firefox", "idevice",
    ):
        require(token not in text, f"retired graph path remains: {token}")

    require(text.count("isa = PBXNativeTarget;") == 5, "Xcode target set is not canonical")
    require(len(text.splitlines()) < 800, "project.pbxproj exceeds 800-line budget")
    test_target = text.split(
        '/* VulpraEngineKitTests */ = {isa = PBXNativeTarget;', 1
    )[1].split('};', 1)[0]
    require('B00000000000000000000006' not in test_target,
            "EngineKit unit tests still depend on the production App test host")
    require('TEST_HOST =' not in text and 'BUNDLE_LOADER =' not in text,
            "EngineKit unit tests still launch through the production App main")
    require('Stage Engine Test Runtime' in test_target,
            "hostless EngineKit tests do not stage their runtime link dependencies")
    require('VULPRA_ENGINE_PRODUCT_BUNDLE' in text and 'VULPRA_ENGINE_FRAMEWORK' in text,
            "EngineKit test staging does not call the shared runtime owner explicitly")

    app = "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "App").rglob("*.swift"))
    require("import VulpraEngineKit" in app, "App is not migrated to VulpraEngineKit")
    require("import GeckoView" not in app and "GeckoSession" not in app, "App retains old engine types")

    for name in ("EngineKit", "EngineProcess"):
        config = (ROOT / f"Configuration/{name}.xcconfig").read_text(encoding="utf-8")
        require("VulpraRuntime" not in config and "Vendor/firefox" not in config,
                f"{name} config retains inherited source")

    staging = (ROOT / "Tools/Engine/stage-engine-runtime.sh").read_text(encoding="utf-8")
    require('VULPRA_ENGINE_PRODUCT_BUNDLE' in staging and 'VULPRA_ENGINE_FRAMEWORK' in staging,
            "runtime staging cannot target a hostless test bundle")
    require('codesign --force --sign - {}' in staging,
            "simulator runtime does not repair the precompiled Mach-O signature")
    require('json.load(open(sys.argv[1]' in staging and '["runtimeResourceContainer"]' in staging,
            "runtime staging does not use the platform artifact contract resource container")
    require('runtimeKernelInstallPath' in staging and 'ENGINE_KERNEL=$FRAMEWORKS/$KERNEL_INSTALL_PATH' in staging,
            "runtime staging does not use the platform kernel install contract")
    require('ENGINE_KERNEL_CONTAINER=$(dirname "$ENGINE_KERNEL")' in staging
            and '"$ENGINE_KERNEL_CONTAINER/Info.plist"' in staging,
            "runtime staging does not keep the kernel bundle separate from resources")
    require('CFBundleExecutable' in staging and 'CFBundleIdentifier' in staging
            and 'CFBundlePackageType' in staging,
            "Simulator XUL carrier lacks an installable framework Info.plist")
    engine_config = (ROOT / "Configuration/EngineKit.xcconfig").read_text(encoding="utf-8")
    require('GeckoView.framework' not in engine_config,
            "EngineKit still carries a layout-specific Simulator search path")
    relocation = (ROOT / "Tools/Engine/relocate-simulator-kernel-link.sh").read_text(
        encoding="utf-8"
    )
    require('install_name_tool -change "@rpath/XUL" "$KERNEL_LINK_PATH"' in relocation,
            "EngineKit post-link phase does not rewrite its Simulator XUL dependency")
    require('install_name_tool -change "@rpath/XUL"' not in staging,
            "App staging still patches the EngineKit consumer too late")
    require('install_name_tool -id "$KERNEL_LINK_PATH" "$ENGINE_KERNEL"' in staging,
            "Simulator staging does not align the installed XUL dylib identity")
    require('KERNEL_LINK_PATH=@rpath/$KERNEL_INSTALL_PATH' in staging,
            "runtime staging does not derive the link path from the install contract")
    require('Frameworks/XUL", );' not in text,
            "Xcode still declares the retired top-level XUL staging output")
    engine_target = text.split('/* VulpraEngineKit */ = {isa = PBXNativeTarget;', 1)[1].split(
        '};', 1
    )[0]
    require('Relocate Simulator Kernel Link' in engine_target,
            "VulpraEngineKit target does not own its post-link relocation")
    require("ENGINE_RUNTIME=$FRAMEWORKS/VulpraEngineRuntime" not in staging,
            "runtime staging hard-codes the resource container instead of using the contract")
    require(not (ROOT / "Configuration/GeckoView.xcconfig").exists(), "old framework config remains")
    require(not (ROOT / "Configuration/Helper.xcconfig").exists(), "old helper config remains")

    ET.parse(SCHEME)
    scheme = SCHEME.read_text(encoding="utf-8")
    for target in ("Vulpra", "OpenIn", "VulpraEngineKit", "Vulpra Engine Process",
                   "VulpraEngineKitTests"):
        require(f'BlueprintName="{target}"' in scheme, f"scheme is missing {target}")
    require("GeckoView" not in scheme and "Vulpra Helper" not in scheme, "scheme retains old targets")

    simulator = SIMULATOR_WORKFLOW.read_text(encoding="utf-8")
    harness = (ROOT / "Tools/CI/run-simulator-navigation.sh").read_text(encoding="utf-8")
    summarizer = (ROOT / "Tools/CI/summarize-r0-engine-gate.py").read_text(encoding="utf-8")
    for token in (
        "Tools/CI/run-simulator-navigation.sh", "Tools/CI/summarize-r0-engine-gate.py",
        "Tools/CI/check-single-attempt-gate.py",
        "r0_attempts:", "name: r0-engine-gate",
    ):
        require(token in simulator, f"simulator evidence does not verify visible content: {token}")
    require('for attempt in $(seq 2 "$attempts")' in simulator,
            "Simulator gate no longer runs a single-attempt fast gate before the repeated loop")
    require("single-attempt navigation gate" in simulator,
            "Simulator gate lacks the single-attempt pass marker")
    for token in (
        "rendered_dark_pixels=", "lifecycleEvents", "requestedLaunchIDs",
        "connectedLaunchIDs", "openLaunchIDs", "trap cleanup EXIT",
        "(height / 4)..<(height * 3 / 4)",
    ):
        require(token in harness, f"Simulator harness is missing evidence field: {token}")
    require("data-vulpra-engine-fixture" in simulator,
            "Simulator workflow lacks a deterministic central page marker")
    require('VulpraEngineRuntime/Frameworks/omni.ja' in simulator,
            "Simulator gate does not require the staged Gecko omnijar")
    require('test -f "$app/Frameworks/VulpraEngineRuntime/Frameworks/defaults/pref/mobile.js"'
            not in simulator,
            "Simulator gate still requires the retired unpacked omnijar layout")
    require('modules/AppConstants.sys.mjs' in simulator and
            'modules/XPCOMUtils.sys.mjs' in simulator,
            "Simulator gate does not inspect required omnijar entries")
    require('build-for-testing 2>&1 | tee simulator-build.log' in simulator,
            "Simulator gate does not build App and unit tests in one build phase")
    require('test-without-building > simulator-native-tests.log' in simulator,
            "native EngineKit execution still mixes compilation into its deadline")
    require('grep -Fq "** TEST EXECUTE SUCCEEDED **" simulator-native-tests.log' in simulator and
            '! grep -Fq "** TEST EXECUTE FAILED **" simulator-native-tests.log' in simulator,
            "native EngineKit gate still checks the retired combined-test result markers")
    require("p95 > 15000" in summarizer and "maximum > 30000" in summarizer,
            "R0 summarizer does not enforce navigation performance thresholds")
    require("lock['simulator']['archive']" in simulator,
            "simulator evidence does not use the pinned simulator engine")
    require("xcrun vtool" not in simulator and "derive_simulator_from_device" not in simulator,
            "simulator workflow still rewrites the device engine")
    log_start = harness.index("log stream --style compact --info --debug")
    navigation_launch = harness.index("LAUNCH_OUTPUT=")
    navigation_screenshot = harness.index('screenshot "$PREFIX-navigation.png"')
    log_stop = harness.rindex('kill "$SYSTEM_LOG_PID"')
    require(log_start < navigation_launch,
            "simulator logging must start before navigation launches")
    require(log_stop > navigation_screenshot,
            "simulator logging must remain active through navigation evidence")
    print("PASS: atomic independent Xcode cutover candidate")


if __name__ == "__main__":
    main()
