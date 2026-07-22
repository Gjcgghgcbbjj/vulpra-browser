#!/usr/bin/env python3
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
workflow = ROOT / '.github/workflows/build-ios-packages.yml'

def require(ok, message):
    if not ok:
        print('FAIL:', message, file=sys.stderr); raise SystemExit(1)

def main():
    require(workflow.is_file(), 'missing iOS package workflow')
    text = workflow.read_text()
    for token in ('workflow_dispatch:', 'runs-on: macos-26', 'runtime-substrate-key.sh',
                  'actions/artifacts', 'gecko-artifact.sh restore', 'libidevice_ffi.a',
                  'verify-runtime-artifacts.sh', 'xcodebuild -list', 'build-app.sh',
                  'create-ipa.sh', 'Vulpra.ipa', 'Vulpra-TrollStore.tipa',
                  'SHA256SUMS', 'actions/upload-artifact@v4'):
        require(token in text, f'missing {token}')
    require('build-runtime-substrate.sh' not in text, 'package workflow must not rebuild Gecko')
    require('build-gecko.sh' not in text, 'package workflow must not rebuild Gecko')
    require('diagnostic_mode' not in text and 'VULPRA_SWIFT_FLAGS' not in text,
            'retired diagnostic compilation path remains')
    print('PASS: GitHub iOS package workflow contracts')
if __name__ == '__main__': main()
