#!/usr/bin/env python3
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import struct
import sys


MACH_HEADER_64 = struct.Struct("<IiiIIIII")
LOAD_COMMAND = struct.Struct("<II")
SYMTAB_COMMAND = struct.Struct("<IIIIII")
LINKEDIT_DATA_COMMAND = struct.Struct("<IIII")
NLIST_64 = struct.Struct("<IBBHQ")
MH_MAGIC_64 = 0xFEEDFACF
CPU_TYPE_ARM64 = 0x0100000C
MH_DYLIB = 6
LC_SYMTAB = 2
LC_DYLD_EXPORTS_TRIE = 0x80000033
N_STAB = 0xE0
N_TYPE = 0x0E
N_UNDF = 0x00


class InventoryError(ValueError):
    pass


def fail(message: str) -> None:
    raise InventoryError(message)


def normalized_path(value: object, label: str) -> str:
    if not isinstance(value, str) or not value:
        fail(f"{label} must be a normalized relative path")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        fail(f"{label} must be a normalized relative path: {value}")
    if path.as_posix() != value or "\\" in value:
        fail(f"{label} must be a normalized relative path: {value}")
    return value


def load_config(path: Path) -> dict[str, object]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"missing inventory configuration: {path}")
    except (OSError, json.JSONDecodeError) as error:
        fail(f"invalid inventory configuration: {path}: {error}")
    if not isinstance(value, dict) or set(value) != {"schemaVersion", "headers", "questions"}:
        fail("inventory configuration keys are invalid")
    if value.get("schemaVersion") != 1:
        fail("inventory configuration schemaVersion must be 1")

    headers = value.get("headers")
    if not isinstance(headers, list) or not headers:
        fail("inventory configuration headers must be a non-empty list")
    normalized_headers = [normalized_path(header, "header path") for header in headers]
    if len(normalized_headers) != len(set(normalized_headers)):
        fail("inventory configuration contains duplicate headers")

    questions = value.get("questions")
    if not isinstance(questions, list) or not questions:
        fail("inventory configuration questions must be a non-empty list")
    ids: list[str] = []
    for index, question in enumerate(questions):
        if not isinstance(question, dict) or set(question) != {"id", "declarationTokens", "exportedSymbols"}:
            fail(f"inventory question {index} keys are invalid")
        question_id = question.get("id")
        if not isinstance(question_id, str) or not question_id:
            fail(f"inventory question {index} id is invalid")
        ids.append(question_id)
        for key in ("declarationTokens", "exportedSymbols"):
            items = question.get(key)
            if not isinstance(items, list) or not items or not all(isinstance(item, str) and item for item in items):
                fail(f"inventory question {question_id} {key} must be a non-empty string list")
            if len(items) != len(set(items)):
                fail(f"inventory question {question_id} contains duplicate {key}")
    if len(ids) != len(set(ids)):
        fail("inventory configuration contains duplicate question ids")
    return value


def resolve_payload(root: Path, relative: str, label: str) -> Path:
    candidate = root / relative
    try:
        resolved_root = root.resolve(strict=True)
        resolved = candidate.resolve(strict=True)
    except FileNotFoundError:
        fail(f"missing {label}: {relative}")
    try:
        resolved.relative_to(resolved_root)
    except ValueError:
        fail(f"{label} escapes layout root: {relative}")
    if candidate.is_symlink() or not resolved.is_file():
        fail(f"{label} must be a regular file: {relative}")
    return resolved


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def checked_range(data: bytes, offset: int, size: int, label: str) -> memoryview:
    if offset < 0 or size < 0 or offset + size > len(data):
        fail(f"Mach-O {label} is outside the kernel")
    return memoryview(data)[offset : offset + size]


def read_uleb128(data: bytes, offset: int, label: str) -> tuple[int, int]:
    value = 0
    shift = 0
    while True:
        if offset >= len(data) or shift >= 64:
            fail(f"Mach-O {label} contains malformed ULEB128 data")
        byte = data[offset]
        offset += 1
        value |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return value, offset
        shift += 7


def parse_export_trie(data: bytes) -> set[str]:
    exports: set[str] = set()
    pending = [(0, "")]
    visited: set[int] = set()
    while pending:
        node, prefix = pending.pop()
        if node in visited or node >= len(data):
            fail("Mach-O export trie contains an invalid or repeated node")
        visited.add(node)
        terminal_size, cursor = read_uleb128(data, node, "export trie")
        terminal_end = cursor + terminal_size
        if terminal_end >= len(data):
            fail("Mach-O export trie terminal is outside the trie")
        if terminal_size:
            exports.add(prefix)
        cursor = terminal_end
        child_count = data[cursor]
        cursor += 1
        for _ in range(child_count):
            try:
                edge_end = data.index(0, cursor)
            except ValueError:
                fail("Mach-O export trie edge is not terminated")
            try:
                edge = data[cursor:edge_end].decode("ascii")
            except UnicodeDecodeError:
                fail("Mach-O export trie edge is not ASCII")
            if not edge:
                fail("Mach-O export trie edge is empty")
            child, cursor = read_uleb128(data, edge_end + 1, "export trie")
            pending.append((child, prefix + edge))
    return exports


def parse_macho_symbols(path: Path, requested: set[str]) -> tuple[dict[str, str], dict[str, object], int]:
    data = path.read_bytes()
    if len(data) < MACH_HEADER_64.size:
        fail("kernel is not a complete 64-bit Mach-O file")
    magic, cpu_type, _, file_type, command_count, command_bytes, _, _ = MACH_HEADER_64.unpack_from(data)
    if magic != MH_MAGIC_64:
        fail("kernel is not a little-endian 64-bit Mach-O file")
    if cpu_type != CPU_TYPE_ARM64:
        fail("Mach-O kernel architecture is not arm64")
    if file_type != MH_DYLIB:
        fail("Mach-O kernel file type is not a dylib")

    commands_start = MACH_HEADER_64.size
    commands_end = commands_start + command_bytes
    checked_range(data, commands_start, command_bytes, "load commands")
    offset = commands_start
    symtab: tuple[int, int, int, int] | None = None
    export_trie: tuple[int, int] | None = None
    for _ in range(command_count):
        if offset + LOAD_COMMAND.size > commands_end:
            fail("Mach-O load command header is truncated")
        command, size = LOAD_COMMAND.unpack_from(data, offset)
        if size < LOAD_COMMAND.size or offset + size > commands_end:
            fail("Mach-O load command is malformed")
        if command == LC_SYMTAB:
            if size < SYMTAB_COMMAND.size:
                fail("Mach-O symbol table command is truncated")
            _, _, symbol_offset, symbol_count, string_offset, string_size = SYMTAB_COMMAND.unpack_from(data, offset)
            if symtab is not None:
                fail("Mach-O contains duplicate symbol tables")
            symtab = (symbol_offset, symbol_count, string_offset, string_size)
        elif command == LC_DYLD_EXPORTS_TRIE:
            if size < LINKEDIT_DATA_COMMAND.size:
                fail("Mach-O export trie command is truncated")
            _, _, trie_offset, trie_size = LINKEDIT_DATA_COMMAND.unpack_from(data, offset)
            if export_trie is not None:
                fail("Mach-O contains duplicate export tries")
            export_trie = (trie_offset, trie_size)
        offset += size
    if offset != commands_end:
        fail("Mach-O load command sizes do not match the header")
    if symtab is None:
        fail("Mach-O kernel has no symbol table")
    if export_trie is None:
        fail("Mach-O kernel has no export trie")

    symbol_offset, symbol_count, string_offset, string_size = symtab
    checked_range(data, symbol_offset, symbol_count * NLIST_64.size, "symbol table")
    strings = checked_range(data, string_offset, string_size, "string table").tobytes()
    states = {name: "absent" for name in requested}
    for index in range(symbol_count):
        entry_offset = symbol_offset + index * NLIST_64.size
        string_index, symbol_type, _, _, _ = NLIST_64.unpack_from(data, entry_offset)
        if symbol_type & N_STAB or string_index == 0:
            continue
        if string_index >= len(strings):
            fail("Mach-O symbol string index is outside the string table")
        end = strings.find(b"\0", string_index)
        if end < 0:
            fail("Mach-O symbol name is not terminated")
        try:
            name = strings[string_index:end].decode("ascii")
        except UnicodeDecodeError:
            fail("Mach-O symbol name is not ASCII")
        if name in requested:
            state = "undefined" if symbol_type & N_TYPE == N_UNDF else "defined-not-exported"
            if states[name] not in {"defined-not-exported", "exported"}:
                states[name] = state
    trie_offset, trie_size = export_trie
    trie = checked_range(data, trie_offset, trie_size, "export trie").tobytes()
    exports = parse_export_trie(trie)
    for name in requested & exports:
        states[name] = "exported"
    identity = {
        "architecture": "arm64",
        "fileType": "dylib",
    }
    return states, identity, len(exports)


def inventory(args: argparse.Namespace) -> dict[str, object]:
    config = load_config(args.config)
    kernel_relative = normalized_path(args.kernel, "kernel path")
    include_relative = normalized_path(args.include_root, "include root")
    if not args.source_artifact_id.strip() or "\n" in args.source_artifact_id:
        fail("source artifact id is invalid")
    if args.source_archive.is_symlink() or not args.source_archive.is_file():
        fail(f"source archive must be a regular file: {args.source_archive}")

    kernel = resolve_payload(args.layout_root, kernel_relative, "kernel")
    requested_symbols = {
        name
        for question in config["questions"]
        for name in question["exportedSymbols"]
    }
    symbols, macho, export_count = parse_macho_symbols(kernel, requested_symbols)
    header_records: list[dict[str, object]] = []
    header_text: dict[str, str] = {}
    for header_relative in config["headers"]:
        layout_relative = PurePosixPath(include_relative, header_relative).as_posix()
        header = resolve_payload(args.layout_root, layout_relative, "ABI header")
        try:
            text = header.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            fail(f"ABI header is not UTF-8: {layout_relative}")
        header_text[header_relative] = text
        header_records.append(
            {
                "path": header_relative,
                "sha256": sha256_file(header),
                "size": header.stat().st_size,
            }
        )

    question_records = []
    for question in config["questions"]:
        declarations = []
        for token in question["declarationTokens"]:
            declarations.append(
                {
                    "token": token,
                    "headers": [path for path, text in header_text.items() if token in text],
                }
            )
        question_records.append(
            {
                "id": question["id"],
                "declarations": declarations,
                "symbols": [
                    {"name": name, "state": symbols.get(name, "absent")}
                    for name in question["exportedSymbols"]
                ],
            }
        )

    return {
        "schemaVersion": 1,
        "assessment": "observed-not-runtime-verified",
        "sourceArtifactId": args.source_artifact_id,
        "sourceArchive": {
            "sha256": sha256_file(args.source_archive),
            "size": args.source_archive.stat().st_size,
        },
        "kernel": {
            "path": kernel_relative,
            "sha256": sha256_file(kernel),
            "size": kernel.stat().st_size,
            "machO": macho,
            "exportedSymbolCount": export_count,
        },
        "headers": header_records,
        "questions": question_records,
        "limitations": [
            "Symbol and declaration presence does not prove a valid startup or shutdown sequence.",
            "Objective-C protocol presence does not prove an independently implemented event or process host.",
            "JIT status reporting does not prove interpreter-only startup.",
        ],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Inventory declarations and Mach-O symbols in a Gecko runtime artifact.")
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--source-artifact-id", required=True)
    parser.add_argument("--source-archive", required=True, type=Path)
    parser.add_argument("--layout-root", required=True, type=Path)
    parser.add_argument("--kernel", required=True)
    parser.add_argument("--include-root", required=True)
    return parser.parse_args()


def main() -> int:
    try:
        result = inventory(parse_args())
    except (InventoryError, OSError) as error:
        print(f"engine-abi-inventory-error: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
