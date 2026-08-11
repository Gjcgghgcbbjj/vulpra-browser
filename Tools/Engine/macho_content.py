"""Signing-independent Mach-O content identity for package validation."""

from __future__ import annotations

import hashlib
import struct


LC_CODE_SIGNATURE = 0x1D
LC_DYSYMTAB = 0xB
LC_SYMTAB = 0x2
LC_UUID = 0x1B
LC_SEGMENT_64 = 0x19
INDIRECT_SYMBOL_ABS = 0x40000000
INDIRECT_SYMBOL_LOCAL = 0x80000000
N_OSO = 0x66
S_NON_LAZY_SYMBOL_POINTERS = 0x6
S_LAZY_SYMBOL_POINTERS = 0x7
S_SYMBOL_STUBS = 0x8
S_ZEROFILL = 0x1
S_THREAD_LOCAL_ZEROFILL = 0x12


class MachOContentError(ValueError):
    pass


def _u32(data: bytes, offset: int, endian: str) -> int:
    return struct.unpack_from(endian + "I", data, offset)[0]


def _u64(data: bytes, offset: int, endian: str) -> int:
    return struct.unpack_from(endian + "Q", data, offset)[0]


def _name(value: bytes) -> bytes:
    return value.split(b"\0", 1)[0]


def _add(hasher: hashlib._Hash, value: bytes) -> None:
    hasher.update(struct.pack(">Q", len(value)))
    hasher.update(value)


def content_identity(data: bytes, label: str) -> str:
    if len(data) < 32:
        raise MachOContentError(f"truncated Mach-O: {label}")
    if data[:4] == b"\xcf\xfa\xed\xfe":
        endian = "<"
    elif data[:4] == b"\xfe\xed\xfa\xcf":
        endian = ">"
    else:
        raise MachOContentError(f"not a thin 64-bit Mach-O: {label}")

    command_count = _u32(data, 16, endian)
    command_bytes = _u32(data, 20, endian)
    command_end = 32 + command_bytes
    if command_end > len(data):
        raise MachOContentError(f"truncated Mach-O commands: {label}")

    hasher = hashlib.sha256()
    _add(hasher, data[:16] + data[24:32])
    offset = 32
    section_count = 0
    for _ in range(command_count):
        if offset + 8 > command_end:
            raise MachOContentError(f"invalid Mach-O command table: {label}")
        command = _u32(data, offset, endian)
        size = _u32(data, offset + 4, endian)
        if size < 8 or offset + size > command_end:
            raise MachOContentError(f"invalid Mach-O command size: {label}")
        if command == LC_CODE_SIGNATURE:
            offset += size
            continue

        normalized = bytearray(data[offset : offset + size])
        if command == LC_SEGMENT_64:
            if size < 72:
                raise MachOContentError(f"truncated segment command: {label}")
            segment_name = _name(data[offset + 8 : offset + 24])
            sections = _u32(data, offset + 64, endian)
            if 72 + sections * 80 > size:
                raise MachOContentError(f"truncated section table: {label}")
            if segment_name == b"__LINKEDIT":
                normalized[32:40] = b"\0" * 8
                normalized[48:56] = b"\0" * 8
            for index in range(sections):
                base = offset + 72 + index * 80
                section_name = _name(data[base : base + 16])
                owner_name = _name(data[base + 16 : base + 32])
                section_size = _u64(data, base + 40, endian)
                file_offset = _u32(data, base + 48, endian)
                flags = _u32(data, base + 64, endian)
                section_type = flags & 0xFF
                _add(hasher, owner_name + b"\0" + section_name)
                _add(hasher, struct.pack(">Q", section_size))
                if section_type not in {S_ZEROFILL, S_THREAD_LOCAL_ZEROFILL}:
                    end = file_offset + section_size
                    if end > len(data):
                        raise MachOContentError(f"truncated section content: {label}")
                    _add(hasher, data[file_offset:end])
                section_count += 1
        _add(hasher, bytes(normalized))
        offset += size

    if offset != command_end:
        raise MachOContentError(f"invalid Mach-O command length: {label}")
    if section_count == 0:
        raise MachOContentError(f"Mach-O has no comparable sections: {label}")
    return hasher.hexdigest()


def is_thin_macho64(data: bytes) -> bool:
    return data[:4] in {b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf"}


def _signed(value: int, bits: int) -> int:
    sign = 1 << (bits - 1)
    return value - (1 << bits) if value & sign else value


def _cstring(data: bytes, start: int, end: int, label: str) -> bytes:
    if start < 0 or start >= end or end > len(data):
        raise MachOContentError(f"invalid Mach-O string offset: {label}")
    terminator = data.find(b"\0", start, end)
    if terminator < 0:
        raise MachOContentError(f"unterminated Mach-O string: {label}")
    return data[start:terminator]


def _pointer_binding(
    first: int,
    second: int,
    pc: int,
    sections: list[dict[str, int | bytes]],
    indirect_symbols: list[int],
    symbol_names: list[bytes],
) -> bytes | None:
    if first & 0x9F000000 != 0x90000000 or second & 0xFFC00000 != 0xF9400000:
        return None
    register = first & 0x1F
    if (second >> 5) & 0x1F != register:
        return None
    immediate = (((first >> 5) & 0x7FFFF) << 2) | ((first >> 29) & 0x3)
    target = (pc & ~0xFFF) + (_signed(immediate, 21) << 12)
    target += ((second >> 10) & 0xFFF) * 8
    for section in sections:
        section_type = int(section["flags"]) & 0xFF
        if section_type not in {S_NON_LAZY_SYMBOL_POINTERS, S_LAZY_SYMBOL_POINTERS}:
            continue
        address = int(section["address"])
        size = int(section["size"])
        if not (address <= target < address + size) or (target - address) % 8:
            continue
        indirect_index = int(section["reserved1"]) + (target - address) // 8
        if indirect_index >= len(indirect_symbols):
            raise MachOContentError("Mach-O indirect symbol index is outside the table")
        symbol_index = indirect_symbols[indirect_index]
        if symbol_index & (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS):
            return struct.pack(">I", symbol_index)
        if symbol_index >= len(symbol_names):
            raise MachOContentError("Mach-O indirect binding has an invalid symbol index")
        return symbol_names[symbol_index]
    return None


def _normalized_stub_content(
    content: bytes,
    section: dict[str, int | bytes],
    sections: list[dict[str, int | bytes]],
    indirect_symbols: list[int],
    symbol_names: list[bytes],
    endian: str,
) -> tuple[bytes, list[bytes]]:
    name = section["name"]
    if name not in {b"__stubs", b"__objc_stubs"}:
        return content, []
    entry_size = int(section["reserved2"]) if name == b"__stubs" else 32
    if entry_size < 8 or len(content) % entry_size:
        raise MachOContentError(f"invalid Mach-O stub section layout: {name.decode()}")
    normalized = bytearray(content)
    bindings: list[bytes] = []
    address = int(section["address"])
    for entry in range(0, len(content), entry_size):
        for relative in range(0, entry_size - 4, 4):
            offset = entry + relative
            first = _u32(content, offset, endian)
            second = _u32(content, offset + 4, endian)
            binding = _pointer_binding(
                first, second, address + offset, sections, indirect_symbols, symbol_names
            )
            if binding is None:
                continue
            first &= ~((0x3 << 29) | (0x7FFFF << 5))
            second &= ~(0xFFF << 10)
            struct.pack_into(endian + "II", normalized, offset, first, second)
            bindings.append(struct.pack(">II", offset, len(binding)) + binding)
    return bytes(normalized), bindings


def repeat_identity(data: bytes, label: str) -> str:
    """Identity for repeat builds, excluding parsed non-semantic linker metadata."""
    if len(data) < 32:
        raise MachOContentError(f"truncated Mach-O: {label}")
    if data[:4] == b"\xcf\xfa\xed\xfe":
        endian = "<"
    elif data[:4] == b"\xfe\xed\xfa\xcf":
        endian = ">"
    else:
        raise MachOContentError(f"not a thin 64-bit Mach-O: {label}")

    command_count = _u32(data, 16, endian)
    command_bytes = _u32(data, 20, endian)
    command_end = 32 + command_bytes
    if command_end > len(data):
        raise MachOContentError(f"truncated Mach-O commands: {label}")

    commands: list[tuple[int, int, int]] = []
    sections: list[dict[str, int | bytes]] = []
    signatures: list[tuple[int, int]] = []
    symbol_table: tuple[int, int, int, int] | None = None
    indirect_table: tuple[int, int] | None = None
    linkedit: tuple[int, int] | None = None
    offset = 32
    for _ in range(command_count):
        if offset + 8 > command_end:
            raise MachOContentError(f"invalid Mach-O command table: {label}")
        command = _u32(data, offset, endian)
        size = _u32(data, offset + 4, endian)
        if size < 8 or offset + size > command_end:
            raise MachOContentError(f"invalid Mach-O command size: {label}")
        commands.append((offset, command, size))
        if command == LC_SEGMENT_64:
            if size < 72:
                raise MachOContentError(f"truncated segment command: {label}")
            segment_name = _name(data[offset + 8 : offset + 24])
            file_offset = _u64(data, offset + 40, endian)
            file_size = _u64(data, offset + 48, endian)
            if file_offset + file_size > len(data):
                raise MachOContentError(f"truncated segment content: {label}")
            if segment_name == b"__LINKEDIT":
                if linkedit is not None:
                    raise MachOContentError(f"duplicate __LINKEDIT segment: {label}")
                linkedit = (file_offset, file_size)
            count = _u32(data, offset + 64, endian)
            if 72 + count * 80 > size:
                raise MachOContentError(f"truncated section table: {label}")
            for index in range(count):
                base = offset + 72 + index * 80
                section_size = _u64(data, base + 40, endian)
                section_offset = _u32(data, base + 48, endian)
                flags = _u32(data, base + 64, endian)
                if flags & 0xFF not in {S_ZEROFILL, S_THREAD_LOCAL_ZEROFILL} \
                        and section_offset + section_size > len(data):
                    raise MachOContentError(f"truncated section content: {label}")
                sections.append({
                    "name": _name(data[base : base + 16]),
                    "owner": _name(data[base + 16 : base + 32]),
                    "address": _u64(data, base + 32, endian),
                    "size": section_size,
                    "offset": section_offset,
                    "flags": flags,
                    "reserved1": _u32(data, base + 68, endian),
                    "reserved2": _u32(data, base + 72, endian),
                })
        elif command == LC_SYMTAB:
            if size < 24 or symbol_table is not None:
                raise MachOContentError(f"invalid Mach-O symbol table command: {label}")
            symbol_table = tuple(_u32(data, offset + value, endian) for value in (8, 12, 16, 20))
        elif command == LC_DYSYMTAB:
            if size < 80 or indirect_table is not None:
                raise MachOContentError(f"invalid Mach-O dynamic symbol table command: {label}")
            indirect_table = (_u32(data, offset + 56, endian), _u32(data, offset + 60, endian))
        elif command == LC_CODE_SIGNATURE:
            if size < 16:
                raise MachOContentError(f"invalid Mach-O code signature command: {label}")
            signatures.append((_u32(data, offset + 8, endian), _u32(data, offset + 12, endian)))
        offset += size
    if offset != command_end or not sections:
        raise MachOContentError(f"invalid Mach-O command length or sections: {label}")

    symbol_names: list[bytes] = []
    if symbol_table is not None:
        symbol_offset, symbol_count, string_offset, string_size = symbol_table
        if symbol_offset + symbol_count * 16 > len(data) or string_offset + string_size > len(data):
            raise MachOContentError(f"truncated Mach-O symbol data: {label}")
        for index in range(symbol_count):
            string_index = _u32(data, symbol_offset + index * 16, endian)
            symbol_names.append(
                b"" if string_index == 0 else _cstring(
                    data, string_offset + string_index, string_offset + string_size, label
                )
            )
    indirect_symbols: list[int] = []
    if indirect_table is not None:
        indirect_offset, indirect_count = indirect_table
        if indirect_offset + indirect_count * 4 > len(data):
            raise MachOContentError(f"truncated Mach-O indirect symbol table: {label}")
        indirect_symbols = [
            _u32(data, indirect_offset + index * 4, endian)
            for index in range(indirect_count)
        ]

    hasher = hashlib.sha256()
    _add(hasher, data[:32])
    for command_offset, command, size in commands:
        if command in {LC_UUID, LC_CODE_SIGNATURE}:
            continue
        normalized = bytearray(data[command_offset : command_offset + size])
        if command == LC_SEGMENT_64 and _name(normalized[8:24]) == b"__LINKEDIT":
            normalized[32:40] = b"\0" * 8
            normalized[48:56] = b"\0" * 8
        _add(hasher, bytes(normalized))

    for section in sections:
        _add(hasher, section["owner"] + b"\0" + section["name"])
        _add(hasher, struct.pack(">Q", int(section["size"])))
        if int(section["flags"]) & 0xFF in {S_ZEROFILL, S_THREAD_LOCAL_ZEROFILL}:
            continue
        start = int(section["offset"])
        content = data[start : start + int(section["size"])]
        normalized, bindings = _normalized_stub_content(
            content, section, sections, indirect_symbols, symbol_names, endian
        )
        _add(hasher, normalized)
        for binding in bindings:
            _add(hasher, binding)

    if linkedit is not None:
        linkedit_offset, linkedit_size = linkedit
        normalized = bytearray(data[linkedit_offset : linkedit_offset + linkedit_size])
        if symbol_table is not None:
            symbol_offset, symbol_count, _, _ = symbol_table
            for index in range(symbol_count):
                entry = symbol_offset + index * 16
                if data[entry + 4] == N_OSO:
                    relative = entry + 8 - linkedit_offset
                    if 0 <= relative <= len(normalized) - 8:
                        normalized[relative : relative + 8] = b"\0" * 8
        for signature_offset, signature_size in sorted(signatures, reverse=True):
            relative = signature_offset - linkedit_offset
            if relative < 0 or relative + signature_size > len(normalized):
                raise MachOContentError(f"code signature is outside __LINKEDIT: {label}")
            del normalized[relative : relative + signature_size]
        _add(hasher, bytes(normalized))
    return hasher.hexdigest()
