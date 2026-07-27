#!/usr/bin/env python3
"""Generate the deterministic White Porcelain Flame V AppIcon asset set."""

import argparse
import json
import math
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "App/Resources/Assets.xcassets"
APPICON = CATALOG / "AppIcon.appiconset"
MASTER = ROOT / "docs/brand/vulpra-icon-master.svg"
SUPERSAMPLE = 4

PORCELAIN = (247, 248, 246)
SEPARATOR = (228, 231, 234)
GRAPHITE = (36, 39, 43)
VERMILION = (232, 93, 69)

ROLES = [
    ("iphone", "20x20", "2x", "AppIcon-20@2x.png"),
    ("iphone", "20x20", "3x", "AppIcon-20@3x.png"),
    ("iphone", "29x29", "2x", "AppIcon-29@2x.png"),
    ("iphone", "29x29", "3x", "AppIcon-29@3x.png"),
    ("iphone", "40x40", "2x", "AppIcon-40@2x.png"),
    ("iphone", "40x40", "3x", "AppIcon-40@3x.png"),
    ("iphone", "60x60", "2x", "AppIcon-60@2x.png"),
    ("iphone", "60x60", "3x", "AppIcon-60@3x.png"),
    ("ipad", "20x20", "1x", "AppIcon-20.png"),
    ("ipad", "20x20", "2x", "AppIcon-20@2x-ipad.png"),
    ("ipad", "29x29", "1x", "AppIcon-29.png"),
    ("ipad", "29x29", "2x", "AppIcon-29@2x-ipad.png"),
    ("ipad", "40x40", "1x", "AppIcon-40.png"),
    ("ipad", "40x40", "2x", "AppIcon-40@2x-ipad.png"),
    ("ipad", "76x76", "1x", "AppIcon-76.png"),
    ("ipad", "76x76", "2x", "AppIcon-76@2x.png"),
    ("ipad", "83.5x83.5", "2x", "AppIcon-83.5@2x.png"),
    ("ios-marketing", "1024x1024", "1x", "AppIcon-1024.png"),
]


def cubic(start, control1, control2, end, steps=14):
    points = []
    for index in range(1, steps + 1):
        value = index / steps
        inverse = 1 - value
        points.append((
            inverse ** 3 * start[0] + 3 * inverse ** 2 * value * control1[0]
            + 3 * inverse * value ** 2 * control2[0] + value ** 3 * end[0],
            inverse ** 3 * start[1] + 3 * inverse ** 2 * value * control1[1]
            + 3 * inverse * value ** 2 * control2[1] + value ** 3 * end[1],
        ))
    return points


def mark_polygons():
    main = [(242, 270), (367, 270)]
    main += cubic(main[-1], (405, 385), (460, 545), (512, 670))
    main += cubic(main[-1], (568, 530), (622, 376), (656, 270))
    main += [(780, 270)]
    main += cubic(main[-1], (721, 466), (649, 663), (566, 807))
    main += cubic(main[-1], (551, 832), (531, 849), (512, 859))
    main += cubic(main[-1], (491, 847), (471, 829), (456, 805))
    main += cubic(main[-1], (375, 658), (303, 462), (242, 270))

    accent = [(656, 270)]
    accent += cubic(accent[-1], (682, 235), (703, 200), (718, 158))
    accent += cubic(accent[-1], (755, 216), (762, 279), (743, 339))
    accent += cubic(accent[-1], (725, 397), (684, 443), (632, 477))
    accent += cubic(accent[-1], (641, 421), (642, 363), (624, 322))
    accent += cubic(accent[-1], (638, 307), (649, 289), (656, 270))
    return main, accent


def fill_scanline(buffer, width, row, start, end, color):
    start = max(0, start)
    end = min(width, end)
    if start >= end:
        return
    offset = (row * width + start) * 3
    buffer[offset : offset + (end - start) * 3] = bytes(color) * (end - start)


def fill_rounded_rect(buffer, width, inset, radius, color):
    left = inset
    right = width - inset
    top = inset
    bottom = width - inset
    for row in range(max(0, top), min(width, bottom)):
        center = row + 0.5
        if center < top + radius:
            distance = top + radius - center
        elif center > bottom - radius:
            distance = center - (bottom - radius)
        else:
            distance = 0
        edge = radius - math.sqrt(max(0, radius * radius - distance * distance))
        fill_scanline(buffer, width, row, math.floor(left + edge), math.ceil(right - edge), color)


def fill_polygon(buffer, width, points, color):
    scaled = [(x * width / 1024, y * width / 1024) for x, y in points]
    minimum = max(0, math.floor(min(y for _, y in scaled)))
    maximum = min(width, math.ceil(max(y for _, y in scaled)))
    for row in range(minimum, maximum):
        scan = row + 0.5
        intersections = []
        for index, (x1, y1) in enumerate(scaled):
            x2, y2 = scaled[(index + 1) % len(scaled)]
            if (y1 <= scan < y2) or (y2 <= scan < y1):
                intersections.append(x1 + (scan - y1) * (x2 - x1) / (y2 - y1))
        intersections.sort()
        for index in range(0, len(intersections) - 1, 2):
            fill_scanline(
                buffer, width, row,
                math.floor(intersections[index]), math.ceil(intersections[index + 1]), color,
            )


def render(size):
    high = size * SUPERSAMPLE
    buffer = bytearray(bytes(PORCELAIN) * high * high)
    fill_rounded_rect(buffer, high, round(high * 0.036), round(high * 0.205), SEPARATOR)
    fill_rounded_rect(buffer, high, round(high * 0.046), round(high * 0.195), PORCELAIN)
    main, accent = mark_polygons()
    fill_polygon(buffer, high, main, GRAPHITE)
    fill_polygon(buffer, high, accent, VERMILION)

    output = bytearray(size * size * 3)
    samples = SUPERSAMPLE * SUPERSAMPLE
    for row in range(size):
        for column in range(size):
            totals = [0, 0, 0]
            for subrow in range(SUPERSAMPLE):
                start = (((row * SUPERSAMPLE + subrow) * high) + column * SUPERSAMPLE) * 3
                for subcolumn in range(SUPERSAMPLE):
                    source = start + subcolumn * 3
                    totals[0] += buffer[source]
                    totals[1] += buffer[source + 1]
                    totals[2] += buffer[source + 2]
            target = (row * size + column) * 3
            output[target : target + 3] = bytes(round(value / samples) for value in totals)
    return bytes(output)


def chunk(kind, payload):
    body = kind + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def png(size, pixels):
    rows = b"".join(b"\x00" + pixels[row * size * 3 : (row + 1) * size * 3] for row in range(size))
    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b"")


def generated_files():
    images = [
        {"idiom": idiom, "size": size, "scale": scale, "filename": filename}
        for idiom, size, scale, filename in ROLES
    ]
    files = {
        CATALOG / "Contents.json": (json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n").encode(),
        APPICON / "Contents.json": (json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n").encode(),
        MASTER: b'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#F7F8F6"/>
  <rect x="38" y="38" width="948" height="948" rx="210" fill="none" stroke="#E4E7EA" stroke-width="10"/>
  <path fill="#24272B" d="M242 270H367C405 385 460 545 512 670C568 530 622 376 656 270H780C721 466 649 663 566 807C551 832 531 849 512 859C491 847 471 829 456 805C375 658 303 462 242 270Z"/>
  <path fill="#E85D45" d="M656 270C682 235 703 200 718 158C755 216 762 279 743 339C725 397 684 443 632 477C641 421 642 363 624 322C638 307 649 289 656 270Z"/>
</svg>
''',
    }
    cache = {}
    for _, size_text, scale_text, filename in ROLES:
        points = float(size_text.split("x", 1)[0])
        scale = int(scale_text.removesuffix("x"))
        size = round(points * scale)
        cache.setdefault(size, png(size, render(size)))
        files[APPICON / filename] = cache[size]
    return files


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    files = generated_files()
    if args.check:
        mismatches = [path.relative_to(ROOT) for path, data in files.items() if not path.is_file() or path.read_bytes() != data]
        if mismatches:
            raise SystemExit("FAIL: generated AppIcon files differ: " + ", ".join(map(str, mismatches)))
        print(f"PASS: deterministic White Porcelain AppIcon ({len(ROLES)} roles)")
        return
    for path, data in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    print(f"Generated White Porcelain AppIcon: {APPICON.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
