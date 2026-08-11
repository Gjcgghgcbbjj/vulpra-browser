#!/usr/bin/env python3
"""Portable fixtures for strict repeat-build Mach-O identity."""

from pathlib import Path
import struct
import sys


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Tools/Engine"))

from macho_content import repeat_identity  # noqa: E402


MACH_HEADER = struct.Struct("<IiiIIIII")
SEGMENT = struct.Struct("<II16sQQQQiiII")
SECTION = struct.Struct("<16s16sQQIIIIIIII")
NLIST = struct.Struct("<IBBHQ")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def metadata_macho(
    uuid: bytes, timestamp: int, signature: bytes, text: bytes,
    regular_symbol_value: int = 0x200,
) -> bytes:
    text_offset = 512
    symbol_offset = 1024
    strings = b"\0fixture.o\0_regular\0"
    string_offset = symbol_offset + NLIST.size * 2
    signature_offset = (string_offset + len(strings) + 15) & ~15
    commands_size = 152 + 72 + 24 + 24 + 16
    header = MACH_HEADER.pack(0xFEEDFACF, 0x0100000C, 0, 6, 5, commands_size, 0, 0)
    text_segment = SEGMENT.pack(
        0x19, 152, b"__TEXT", 0, 4096, 0, symbol_offset, 5, 5, 1, 0
    )
    text_section = SECTION.pack(
        b"__text", b"__TEXT", text_offset, len(text), text_offset,
        0, 0, 0, 0, 0, 0, 0,
    )
    linkedit_size = signature_offset + len(signature) - symbol_offset
    linkedit = SEGMENT.pack(
        0x19, 72, b"__LINKEDIT", symbol_offset, linkedit_size,
        symbol_offset, linkedit_size, 1, 1, 0, 0,
    )
    uuid_command = struct.pack("<II16s", 0x1B, 24, uuid)
    symtab = struct.pack("<IIIIII", 0x2, 24, symbol_offset, 2, string_offset, len(strings))
    signature_command = struct.pack("<IIII", 0x1D, 16, signature_offset, len(signature))
    prefix = header + text_segment + text_section + linkedit + uuid_command + symtab + signature_command
    symbols = (
        NLIST.pack(1, 0x66, 0, 1, timestamp)
        + NLIST.pack(11, 0x0F, 1, 0, regular_symbol_value)
    )
    return (
        prefix.ljust(text_offset, b"\0") + text
    ).ljust(symbol_offset, b"\0") + symbols + strings.ljust(signature_offset - string_offset, b"\0") + signature


def pointer_load(target: int) -> tuple[int, int]:
    page = target >> 12
    immediate = page & 0x1FFFFF
    adrp = 0x90000010 | ((immediate & 0x3) << 29) | ((immediate >> 2) << 5)
    ldr = 0xF9400210 | (((target & 0xFFF) // 8) << 10)
    return adrp, ldr


def stub_macho(swapped: bool, tamper_branch: bool = False) -> bytes:
    text_offset = 1024
    objc_offset = text_offset + 12
    got_offset = 2048
    linkedit_offset = 4096
    regular_target = got_offset + (8 if swapped else 0)
    objc_target = got_offset + (0 if swapped else 8)
    regular = (*pointer_load(regular_target), 0xD503201F if tamper_branch else 0xD61F0200)
    objc = (
        0xD503201F, 0xD503201F, *pointer_load(objc_target),
        0xD61F0200, 0xD503201F, 0xD503201F, 0xD503201F,
    )
    text = struct.pack("<3I", *regular) + struct.pack("<8I", *objc)
    strings = b"\0_objc_msgSend\0"
    symbol_offset = linkedit_offset
    string_offset = symbol_offset + NLIST.size
    indirect_offset = (string_offset + len(strings) + 3) & ~3
    indirect = struct.pack("<3I", 0, 0, 0)
    linkedit_size = indirect_offset + len(indirect) - linkedit_offset

    text_command_size = 72 + 80 * 2
    data_command_size = 72 + 80
    commands_size = text_command_size + data_command_size + 72 + 24 + 80
    header = MACH_HEADER.pack(0xFEEDFACF, 0x0100000C, 0, 6, 5, commands_size, 0, 0)
    text_segment = SEGMENT.pack(
        0x19, text_command_size, b"__TEXT", text_offset, len(text),
        text_offset, len(text), 5, 5, 2, 0,
    )
    stubs = SECTION.pack(
        b"__stubs", b"__TEXT", text_offset, 12, text_offset,
        2, 0, 0, 0x80000008, 0, 12, 0,
    )
    objc_stubs = SECTION.pack(
        b"__objc_stubs", b"__TEXT", objc_offset, 32, objc_offset,
        2, 0, 0, 0x80000400, 0, 0, 0,
    )
    data_segment = SEGMENT.pack(
        0x19, data_command_size, b"__DATA_CONST", got_offset, 16,
        got_offset, 16, 3, 3, 1, 0,
    )
    got = SECTION.pack(
        b"__got", b"__DATA_CONST", got_offset, 16, got_offset,
        3, 0, 0, 0x6, 1, 0, 0,
    )
    linkedit = SEGMENT.pack(
        0x19, 72, b"__LINKEDIT", linkedit_offset, linkedit_size,
        linkedit_offset, linkedit_size, 1, 1, 0, 0,
    )
    symtab = struct.pack("<IIIIII", 0x2, 24, symbol_offset, 1, string_offset, len(strings))
    dysymtab_values = [0] * 18
    dysymtab_values[12] = indirect_offset
    dysymtab_values[13] = 3
    dysymtab = struct.pack("<II18I", 0xB, 80, *dysymtab_values)
    prefix = header + text_segment + stubs + objc_stubs + data_segment + got + linkedit + symtab + dysymtab
    symbol = NLIST.pack(1, 0x01, 0, 0, 0)
    return (
        prefix.ljust(text_offset, b"\0") + text
    ).ljust(got_offset, b"\0") + bytes(16) + bytes(linkedit_offset - got_offset - 16) \
        + symbol + strings.ljust(indirect_offset - string_offset, b"\0") + indirect


def main() -> None:
    first = metadata_macho(b"A" * 16, 100, b"first-signature", b"same-code")
    second = metadata_macho(
        b"B" * 16, 200, b"replacement-signature-with-another-size", b"same-code"
    )
    require(
        repeat_identity(first, "first") == repeat_identity(second, "second"),
        "repeat identity retained UUID, signature, or N_OSO timestamp metadata",
    )
    changed_code = metadata_macho(b"B" * 16, 200, b"other", b"changed-code")
    require(
        repeat_identity(first, "first") != repeat_identity(changed_code, "changed-code"),
        "repeat identity normalized away changed section content",
    )
    changed_symbol = metadata_macho(
        b"B" * 16, 200, b"other", b"same-code", regular_symbol_value=0x208
    )
    require(
        repeat_identity(first, "first") != repeat_identity(changed_symbol, "changed-symbol"),
        "repeat identity normalized away a non-N_OSO symbol value",
    )

    original_stubs = stub_macho(False)
    swapped_stubs = stub_macho(True)
    require(
        repeat_identity(original_stubs, "stubs-a") == repeat_identity(swapped_stubs, "stubs-b"),
        "repeat identity retained equivalent duplicate-symbol GOT slot selection",
    )
    require(
        repeat_identity(original_stubs, "stubs-a") != repeat_identity(
            stub_macho(True, tamper_branch=True), "tampered-stubs"
        ),
        "repeat identity normalized away a changed stub branch instruction",
    )
    print("PASS: strict repeat-build Mach-O identity")


if __name__ == "__main__":
    main()
