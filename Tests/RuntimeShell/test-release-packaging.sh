#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
for name in build-app.sh package-app.sh create-ipa.sh; do
	[ -f "$ROOT/Tools/Release/$name" ] || { echo "FAIL: missing Tools/Release/$name" >&2; exit 1; }
done
[ -f "$ROOT/Tools/Engine/validate-ipa.py" ] || { echo "FAIL: missing IPA validator" >&2; exit 1; }
[ ! -e "$ROOT/Tools/Release/build-ptrace-jit.sh" ] || { echo "FAIL: retired ptrace producer remains" >&2; exit 1; }

fail() { echo "FAIL: $*" >&2; exit 1; }
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
archive="$fixture/Vulpra.xcarchive"
app="$archive/Products/Applications/Vulpra.app"
manifest="$fixture/manifest.json"
lock="$fixture/engine-artifact-lock.json"

python3 - "$app" "$manifest" "$lock" "$ROOT/Configuration/build-identity.json" <<'PY'
from pathlib import Path
import hashlib, json, plistlib, struct, sys

app, manifest_path, lock_path, identity_path = map(Path, sys.argv[1:])
identity = json.loads(identity_path.read_text(encoding="utf-8"))
bundles = {
    app: ("com.vulpra.browser", "Vulpra", "APPL"),
    app / "Frameworks/VulpraEngineKit.framework":
        ("com.vulpra.browser.engine-kit", "VulpraEngineKit", "FMWK"),
    app / "PlugIns/Vulpra Engine Process.appex":
        ("com.vulpra.browser.engine-process", "Vulpra Engine Process", "XPC!"),
    app / "PlugIns/OpenIn.appex":
        ("com.vulpra.browser.open-in", "OpenIn", "XPC!"),
}
macho = struct.pack("<IiiIIIII", 0xFEEDFACF, 0x0100000C, 0, 2, 0, 0, 0, 0)
for bundle, (bundle_id, executable, package_type) in bundles.items():
    bundle.mkdir(parents=True, exist_ok=True)
    executable_data = macho
    if bundle == app:
        executable_data += identity["uiFingerprint"].encode("ascii") + b"\x00"
    (bundle / executable).write_bytes(executable_data)
    (bundle / executable).chmod(0o755)
    with (bundle / "Info.plist").open("wb") as sink:
        info = {"CFBundleIdentifier": bundle_id, "CFBundleExecutable": executable,
                "CFBundlePackageType": package_type}
        if bundle == app:
            info.update({"CFBundleShortVersionString": identity["marketingVersion"],
                         "CFBundleVersion": identity["buildVersion"],
                         "VulpraUIBuildFingerprint": identity["uiFingerprint"],
                         "VulpraDistributionProfile": "external-signing"})
        plistlib.dump(info, sink)

payload = {
    "runtime/bin/XUL": macho + b"native-gecko-kernel",
    "runtime/lib/libfixture.dylib": macho,
    "runtime/resources/application.ini": b"[App]\n",
    "licenses/LICENSE.txt": b"license\n",
}
destinations = {
    "runtime/bin/XUL": app / "Frameworks/XUL",
    "runtime/lib/libfixture.dylib": app / "Frameworks/libfixture.dylib",
    "runtime/resources/application.ini": app / "Frameworks/VulpraEngineRuntime/Frameworks/application.ini",
    "licenses/LICENSE.txt": app / "Frameworks/VulpraEngineRuntime/Licenses/LICENSE.txt",
}
entries = []
for relative, content in payload.items():
    destination = destinations[relative]
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(content)
    entries.append({"path": relative, "size": len(content), "sha256": hashlib.sha256(content).hexdigest()})
artifact_id = "vulpra-gecko-ios-arm64-v5-" + "a" * 64
source_commit = "2" * 40
patch_sha = "3" * 64
configuration_sha = "4" * 64
producer_commit = "5" * 40
abi_version = "gecko-ios-v5-abi-1"
manifest_path.write_text(json.dumps({
    "formatVersion": 5, "artifactId": artifact_id, "abiVersion": abi_version,
    "source": {"repository": "https://example.invalid/firefox", "commit": source_commit},
    "patchSet": {"series": "fixture-series.json", "sha256": patch_sha},
    "producer": {"repository": "https://example.invalid/vulpra", "commit": producer_commit,
                 "workflowRunId": 123},
    "compiledBy": {"repository": "https://example.invalid/vulpra", "commit": producer_commit,
                  "workflowRunId": 123, "buildFingerprint": "7" * 64},
    "configurationSHA256": configuration_sha,
    "build": {"platform": "iphoneos", "targetTriple": "aarch64-apple-ios",
              "architecture": "arm64", "deploymentTarget": "15.0",
              "mozconfigSHA256": "6" * 64, "xcodeBuild": "17E202", "sdkBuild": "23E252"},
    "files": entries,
}), encoding="utf-8")
lock_path.write_text(json.dumps({
    "schemaVersion": 2, "artifactFormatVersion": 5,
    "producerRunId": 123, "producerHeadSha": producer_commit,
    "device": {"artifactId": artifact_id, "abiVersion": abi_version,
               "sourceCommit": source_commit, "patchSetSHA256": patch_sha,
               "configurationSHA256": configuration_sha,
               "platform": "iphoneos", "targetTriple": "aarch64-apple-ios",
               "compiledByRunId": 123, "compiledByHeadSha": producer_commit,
               "buildFingerprint": "7" * 64},
}), encoding="utf-8")
PY

tree_hash() {
	find "$1" -type f -print | LC_ALL=C sort | while IFS= read -r file; do sha256sum "$file"; done | sha256sum | awk '{print $1}'
}
before=$(tree_hash "$archive")
mkdir -p "$fixture/out"
"$ROOT/Tools/Release/package-app.sh" "$archive" Products/Applications/Vulpra.app \
	"$fixture/stage" "$fixture/out/Vulpra.ipa"
after=$(tree_hash "$archive")
[ "$before" = "$after" ] || fail "packager modified the archive"
python3 "$ROOT/Tools/Engine/validate-ipa.py" --manifest "$manifest" --lock "$lock" \
  "$fixture/out/Vulpra.ipa"
unzip -p "$fixture/out/Vulpra.ipa" \
  "Payload/Vulpra.app/Frameworks/VulpraEngineRuntime/Frameworks/defaults/pref/vulpra-main-jit.js" \
  | grep -Fq 'pref("javascript.options.main_process_disable_jit", false);' \
  || fail "packaged IPA is missing the main-process JIT default pref"

first=$(sha256sum "$fixture/out/Vulpra.ipa" | awk '{print $1}')
"$ROOT/Tools/Release/package-app.sh" "$archive" Products/Applications/Vulpra.app \
	"$fixture/repeat" "$fixture/out/Vulpra.ipa"
[ "$first" = "$(sha256sum "$fixture/out/Vulpra.ipa" | awk '{print $1}')" ] || fail "package is not deterministic"

mv "$app/Frameworks/XUL" "$app/Frameworks/XUL.missing"
if "$ROOT/Tools/Release/package-app.sh" "$archive" Products/Applications/Vulpra.app \
	"$fixture/missing" "$fixture/out/missing.ipa" >/dev/null 2>&1; then
	fail "missing XUL was accepted"
fi
mv "$app/Frameworks/XUL.missing" "$app/Frameworks/XUL"

mkdir -p "$app/Frameworks/GeckoView.framework"
if "$ROOT/Tools/Release/package-app.sh" "$archive" Products/Applications/Vulpra.app \
	"$fixture/retired" "$fixture/out/retired.ipa" >/dev/null 2>&1; then
	fail "retired framework was accepted"
fi

grep -Fq 'generic/platform=iOS' "$ROOT/Tools/Release/build-app.sh" || fail "archive destination is wrong"
grep -Fq 'engine-artifact-device-v5.json' "$ROOT/Tools/Release/build-app.sh" || fail "archive does not verify v5 artifact"
grep -Fq 'VulpraEngineKit.framework/VulpraEngineKit' "$ROOT/Tools/Release/create-ipa.sh" || fail "EngineKit signing is missing"
grep -Fq 'Vulpra Engine Process.appex/Vulpra Engine Process' "$ROOT/Tools/Release/create-ipa.sh" || fail "process signing is missing"
if grep -R -n -E 'GeckoView.framework|Vulpra Helper|ptrace|idevice|Tools/(Gecko|Runtime)' "$ROOT/Tools/Release"; then
	fail "release scripts retain an old runtime path"
fi

for script in "$ROOT"/Tools/Release/*.sh; do
	sh -n "$script"
	[ "$(wc -l < "$script" | tr -d ' ')" -lt 250 ] || fail "release script exceeds 250 lines"
done

echo "PASS: deterministic independent-engine packaging"
