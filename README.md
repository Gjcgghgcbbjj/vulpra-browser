# Vulpra Browser

Vulpra is a UIKit browser for iOS 15 and later. The application consumes one
independent engine boundary:

```text
Precompiled Gecko Runtime -> VulpraEngineKit -> Vulpra App
```

`VulpraEngineKit` owns the direct runtime ABI, message routing, sessions, and
views. `Vulpra Engine Process` owns child-process bootstrap. The App owns browser
state through `TabManager` and `BrowserTab`; normal-tab Codable records remain
compatible and private tabs remain excluded from persistence. `OpenIn` remains
the sole share extension.

The repository does not build or patch Gecko. A normal build consumes a
content-bound v5 artifact from `.build/engine` containing only XUL, runtime
dylibs, direct ABI headers, resources, licenses, notices, and its manifest.
The active Xcode graph contains four targets: Vulpra, OpenIn, VulpraEngineKit,
and Vulpra Engine Process.

Portable verification:

```sh
./Tests/IndependentEngine/run-portable.sh
./Tests/RuntimeShell/run-portable.sh
./Tests/Browser/run-portable.sh
python3 Tools/Engine/verify-engine-artifact.py \
  --contract Configuration/engine-artifact-device-v5.json .build/engine
```

Mac build and packaging:

```sh
./Tools/Release/build-app.sh
./Tools/Release/create-ipa.sh
python3 Tools/Engine/validate-ipa.py dist/Vulpra.ipa
```

The GitHub workflows restore pinned native Gecko v5 device and Simulator
artifacts, verify them before Xcode runs, compile the independent graph,
exercise Simulator launch/navigation, and publish validated IPA/TIPA packages
with SHA-256 sums.

Architecture requirements and evidence gates are recorded in
`docs/aegis/specs/`, `docs/aegis/adr/`, and
`Configuration/engine-cutover-gates.json`.
