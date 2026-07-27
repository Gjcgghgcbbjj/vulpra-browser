"""Signing-independent Mach-O content identity for package validation."""

from __future__ import annotations

import hashlib
import struct


LC_CODE_SIGNATURE = 0x1D
LC_SEGMENT_64 = 0x19
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
