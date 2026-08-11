#!/bin/bash
# Shared Simulator screenshot render audit.
#
# Usage: audit-rendering.sh PNG [OUTFILE]
# Runs the dark-pixel render audit on a Simulator screenshot and writes
# `rendered_dark_pixels=N` to OUTFILE (default: stdout). The audit counts
# pixels darker than 220/220/220 in the central region (middle half height,
# middle 3/4 width), the same region every Simulator gate summarizer uses to
# prove the engine surface actually composited content.
#
# The exit code is always 0: the audit result is data, not a gate. Semantic
# gates live in the per-gate summarizers. If swift is unavailable or the PNG
# cannot be decoded, the output is rendered_dark_pixels=0 and the caller
# decides what that means (recapture or fail).
set -uo pipefail

png=${1:?usage: audit-rendering.sh PNG [OUTFILE]}
out=${2:-/dev/stdout}

if [[ ! -f "$png" || ! -s "$png" ]]; then
  printf 'rendered_dark_pixels=0\n' > "$out"
  exit 0
fi

set +e
swift - "$png" <<'SWIFT' > "$out" 2>&1
import CoreGraphics
import Darwin
import Foundation
import ImageIO

let path = CommandLine.arguments[1]
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("unable to decode simulator screenshot\n", stderr)
    exit(1)
}
let width = image.width
let height = image.height
var pixels = [UInt8](repeating: 255, count: width * height * 4)
let drewImage = pixels.withUnsafeMutableBytes { buffer -> Bool in
    guard let context = CGContext(
        data: buffer.baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return false }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return true
}
guard drewImage else { exit(1) }
var darkPixels = 0
for y in (height / 4)..<(height * 3 / 4) {
    for x in (width / 8)..<(width * 7 / 8) {
        let offset = (y * width + x) * 4
        if pixels[offset] < 220 && pixels[offset + 1] < 220 && pixels[offset + 2] < 220 {
            darkPixels += 1
        }
    }
}
print("rendered_dark_pixels=\(darkPixels)")
SWIFT
status=$?
set -e
if [[ "$status" -ne 0 ]]; then
  printf 'rendered_dark_pixels=0\n' > "$out"
fi
exit 0
