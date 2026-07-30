#!/usr/bin/env python3
import json
from pathlib import Path
import struct
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "Configuration/engine-abi-inventory.json"
INVENTORY = ROOT / "Tools/Engine/inventory-engine-abi.py"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def export_trie(names: list[str]) -> bytes:
    root_size = 2 + sum(len(name.encode("ascii")) + 2 for name in names)
    require(root_size < 128, "test export trie root exceeds single-byte ULEB128")
    root = bytearray((0, len(names)))
    leaves = bytearray()
    for index, name in enumerate(names):
        root.extend(name.encode("ascii") + b"\0")
        root.append(root_size + index * 4)
        leaves.extend((2, 0, 0, 0))
    return bytes(root + leaves)


def macho64_arm64(symbols: list[tuple[str, bool]], exports: list[str], dyld_info: bool = False) -> bytes:
    strings = bytearray(b"\0")
    entries = bytearray()
    for index, (name, defined) in enumerate(symbols):
        string_index = len(strings)
        strings.extend(name.encode("ascii") + b"\0")
        symbol_type = 0x0F if defined else 0x01
        entries.extend(struct.pack("<IBBHQ", string_index, symbol_type, 1 if defined else 0, 0, 0x1000 + index))

    trie = export_trie(exports)
    header_size = 32
    export_command_size = 48 if dyld_info else 16
    command_size = 24 + export_command_size
    symbol_offset = header_size + command_size
    string_offset = symbol_offset + len(entries)
    trie_offset = string_offset + len(strings)
    header = struct.pack("<IiiIIIII", 0xFEEDFACF, 0x0100000C, 0, 6, 2, command_size, 0, 0)
    symtab = struct.pack("<IIIIII", 2, 24, symbol_offset, len(symbols), string_offset, len(strings))
    if dyld_info:
        exports_command = struct.pack(
            "<IIIIIIIIIIII", 0x80000022, 48,
            0, 0, 0, 0, 0, 0, 0, 0, trie_offset, len(trie),
        )
    else:
        exports_command = struct.pack("<IIII", 0x80000033, 16, trie_offset, len(trie))
    return header + symtab + exports_command + entries + strings + trie


def write_fixture(root: Path) -> tuple[Path, Path, Path]:
    layout = root / "layout"
    include = layout / "include"
    (layout / "bin").mkdir(parents=True)
    (include / "Gecko").mkdir(parents=True)
    (layout / "bin/XUL").write_bytes(
        macho64_arm64(
            [
                ("_MainProcessInit", True),
                ("_ChildProcessInit", True),
                ("_DeclaredButUndefined", False),
            ],
            ["_MainProcessInit"],
        )
    )
    (include / "Gecko/Bootstrap.h").write_text(
        "int MainProcessInit(void);\nvoid ChildProcessInit(void);\n",
        encoding="utf-8",
    )
    archive = root / "source.zip"
    archive.write_bytes(b"pinned-source-archive")
    config = root / "inventory.json"
    config.write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "headers": ["Gecko/Bootstrap.h"],
                "questions": [
                    {
                        "id": "startup",
                        "declarationTokens": ["MainProcessInit", "MissingDeclaration"],
                        "exportedSymbols": [
                            "_MainProcessInit",
                            "_ChildProcessInit",
                            "_DeclaredButUndefined",
                            "_Absent",
                        ],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    return layout, archive, config


def run_inventory(layout: Path, archive: Path, config: Path, *extra: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            "python3",
            str(INVENTORY),
            "--config",
            str(config),
            "--source-artifact-id",
            "fixture-runtime-artifact",
            "--source-archive",
            str(archive),
            "--layout-root",
            str(layout),
            "--kernel",
            "bin/XUL",
            "--include-root",
            "include",
            *extra,
        ],
        text=True,
        capture_output=True,
        check=False,
    )


def main() -> None:
    require(CONFIG.is_file(), "missing ABI inventory configuration")
    require(INVENTORY.is_file(), "missing ABI inventory tool")
    production = json.loads(CONFIG.read_text(encoding="utf-8"))
    require(production.get("schemaVersion") == 1, "ABI inventory schemaVersion must be 1")
    question_ids = [question.get("id") for question in production.get("questions", [])]
    require(
        question_ids
        == [
            "process-wide-startup",
            "process-wide-shutdown",
            "session-window-creation",
            "event-bridge",
            "child-process-bootstrap",
            "child-process-lifecycle",
        ],
        "ABI investigation questions are incomplete or out of order",
    )

    with tempfile.TemporaryDirectory(prefix="vulpra-abi-inventory-") as temporary:
        layout, archive, config = write_fixture(Path(temporary))
        first = run_inventory(layout, archive, config)
        second = run_inventory(layout, archive, config)
        require(first.returncode == 0, f"valid ABI fixture rejected: {first.stderr}")
        require(first.stdout == second.stdout, "ABI inventory output is not deterministic")

        result = json.loads(first.stdout)
        require(result.get("schemaVersion") == 1, "inventory output schemaVersion is invalid")
        require(result.get("assessment") == "observed-not-runtime-verified", "inventory overstates its evidence")
        require(result["kernel"]["machO"] == {"architecture": "arm64", "fileType": "dylib"}, "Mach-O identity is wrong")
        require(len(result["sourceArchive"]["sha256"]) == 64, "source archive is not checksum-bound")
        question = result["questions"][0]
        declarations = {item["token"]: item["headers"] for item in question["declarations"]}
        require(declarations["MainProcessInit"] == ["Gecko/Bootstrap.h"], "header declaration was not recorded")
        require(declarations["MissingDeclaration"] == [], "missing declaration was fabricated")
        symbols = {item["name"]: item["state"] for item in question["symbols"]}
        require(symbols["_MainProcessInit"] == "exported", "exported symbol was not recognized")
        require(symbols["_ChildProcessInit"] == "defined-not-exported", "local definition was treated as exported")
        require(symbols["_DeclaredButUndefined"] == "undefined", "undefined symbol was treated as exported")
        require(symbols["_Absent"] == "absent", "absent symbol was fabricated")

        (layout / "bin/XUL").write_bytes(
            macho64_arm64(
                [("_MainProcessInit", True), ("_ChildProcessInit", True)],
                ["_MainProcessInit"],
                dyld_info=True,
            )
        )
        modern = run_inventory(layout, archive, config)
        require(modern.returncode == 0, f"LC_DYLD_INFO_ONLY ABI fixture rejected: {modern.stderr}")
        modern_symbols = {
            item["name"]: item["state"]
            for item in json.loads(modern.stdout)["questions"][0]["symbols"]
        }
        require(modern_symbols["_MainProcessInit"] == "exported",
                "LC_DYLD_INFO_ONLY export was not recognized")

        unsafe = run_inventory(layout, archive, config, "--kernel", "../XUL")
        require(unsafe.returncode != 0 and "normalized relative path" in unsafe.stderr, "unsafe kernel path was accepted")

        bad_kernel = layout / "bin/XUL"
        bad_kernel.write_bytes(b"not-mach-o")
        malformed = run_inventory(layout, archive, config)
        require(malformed.returncode != 0 and "Mach-O" in malformed.stderr, "malformed kernel was accepted")

    print("PASS: deterministic Gecko ABI inventory")


if __name__ == "__main__":
    main()
