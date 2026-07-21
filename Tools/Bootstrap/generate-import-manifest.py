#!/usr/bin/env python3
"""Generate a deterministic manifest for an allowlisted Git-tree import."""

import argparse
import hashlib
import os
import posixpath
import shutil
import stat
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Mapping:
    source: str
    target: str
    is_tree: bool


@dataclass(frozen=True)
class ImportFile:
    source: str
    target: str


def canonical_commit(source_repo, source_ref):
    try:
        return subprocess.check_output(
            [
                "git",
                "-C",
                source_repo,
                "rev-parse",
                "--verify",
                f"{source_ref}^{{commit}}",
            ],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except subprocess.CalledProcessError as error:
        raise SystemExit(f"Invalid source commit: {source_ref}") from error


def canonical_relative_path(raw_path, label):
    if not raw_path or "\0" in raw_path or "\n" in raw_path or "\t" in raw_path:
        raise SystemExit(f"Invalid {label} path: {raw_path!r}")
    normalized = posixpath.normpath(raw_path)
    if posixpath.isabs(raw_path) or normalized in ("", ".", ".."):
        raise SystemExit(f"Unsafe {label} path: {raw_path}")
    if normalized.startswith("../") or normalized != raw_path:
        raise SystemExit(f"Non-canonical {label} path: {raw_path}")
    return normalized


def read_allowlist(allowlist):
    mappings = []
    with open(allowlist, encoding="utf-8") as source:
        for line_number, raw_line in enumerate(source, 1):
            line = raw_line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) != 2:
                raise SystemExit(f"Invalid allowlist row {line_number}: expected two columns")
            source_path = canonical_relative_path(fields[0], "source")
            target_path = canonical_relative_path(fields[1], "target")
            mappings.append((source_path, target_path))
    return mappings


def git_tree_files(source_repo, commit, source_path):
    try:
        output = subprocess.check_output(
            [
                "git",
                "-C",
                source_repo,
                "ls-tree",
                "-r",
                "-z",
                "--full-tree",
                commit,
                "--",
                source_path,
            ],
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError as error:
        raise SystemExit(f"Unable to inspect source path: {source_path}") from error

    entries = []
    for record in output.split(b"\0"):
        if not record:
            continue
        metadata, encoded_path = record.split(b"\t", 1)
        mode, object_type, _object_id = metadata.decode("ascii").split(" ")
        try:
            path = encoded_path.decode("utf-8")
        except UnicodeDecodeError as error:
            raise SystemExit("Git source path is not valid UTF-8") from error
        if any(character in path for character in ("\0", "\t", "\r", "\n")):
            raise SystemExit(f"Git source path contains an unsafe character: {path!r}")
        canonical_relative_path(path, "expanded source")
        if object_type != "blob" or mode not in ("100644", "100755"):
            raise SystemExit(f"Source is not a regular file: {path}")
        entries.append(path)

    if not entries:
        raise SystemExit(f"Source path is absent from commit: {source_path}")
    exact = [path for path in entries if path == source_path]
    if exact:
        if len(entries) != 1:
            raise SystemExit(f"Ambiguous source path: {source_path}")
        return False, exact
    prefix = source_path + "/"
    if any(not path.startswith(prefix) for path in entries):
        raise SystemExit(f"Ambiguous source tree: {source_path}")
    return True, entries


def reject_target_collisions(files):
    targets = sorted(import_file.target for import_file in files)
    for index, target in enumerate(targets):
        if index and target == targets[index - 1]:
            raise SystemExit(f"Duplicate expanded target: {target}")
    target_set = set(targets)
    for target in targets:
        parent = posixpath.dirname(target)
        while parent and parent != ".":
            if parent in target_set:
                raise SystemExit(f"Target file/directory conflict: {parent} and {target}")
            parent = posixpath.dirname(parent)


def build_import_plan(source_repo, commit, allowlist):
    mappings = []
    files = []
    literal_targets = set()
    for source_path, target_path in read_allowlist(allowlist):
        if target_path in literal_targets:
            raise SystemExit(f"Duplicate literal target: {target_path}")
        literal_targets.add(target_path)
        is_tree, source_files = git_tree_files(source_repo, commit, source_path)
        mappings.append(Mapping(source_path, target_path, is_tree))
        for source_file in source_files:
            if is_tree:
                relative = source_file[len(source_path) + 1 :]
                expanded_target = posixpath.join(target_path, relative)
            else:
                expanded_target = target_path
            canonical_relative_path(expanded_target, "expanded target")
            files.append(ImportFile(source_file, expanded_target))
    reject_target_collisions(files)
    return mappings, sorted(files, key=lambda item: item.target)


def _existing_components(path):
    absolute = os.path.abspath(path)
    components = Path(absolute).parts
    current = components[0]
    for component in components[1:]:
        current = os.path.join(current, component)
        if os.path.lexists(current):
            yield current


def validate_target_paths(target_root, files, mappings=()):
    root = os.path.abspath(target_root)
    replaceable_tree_roots = {
        os.path.join(root, *mapping.target.split("/"))
        for mapping in mappings
        if mapping.is_tree
    }
    for component in _existing_components(root):
        if os.path.islink(component):
            raise SystemExit(f"Symlinked target root component: {component}")
        if not os.path.isdir(component) and component != root:
            raise SystemExit(f"Target root parent is not a directory: {component}")
        if component == root and not os.path.isdir(component):
            raise SystemExit(f"Target root is not a directory: {component}")
    for import_file in files:
        destination = os.path.join(root, *import_file.target.split("/"))
        parent = os.path.dirname(destination)
        for component in _existing_components(parent):
            if os.path.islink(component):
                raise SystemExit(f"Symlinked destination parent: {component}")
            if not os.path.isdir(component) and component not in replaceable_tree_roots:
                raise SystemExit(f"Destination parent is not a directory: {component}")
        if os.path.lexists(destination) and os.path.islink(destination):
            raise SystemExit(f"Symlinked destination: {destination}")
    return root


def validate_manifest_destination(manifest):
    manifest_path = os.path.abspath(manifest)
    parent = os.path.dirname(manifest_path) or "."
    for component in _existing_components(parent):
        if os.path.islink(component):
            raise SystemExit(f"Symlinked manifest parent: {component}")
        if not os.path.isdir(component):
            raise SystemExit(f"Manifest parent is not a directory: {component}")
    if not os.path.isdir(parent):
        raise SystemExit(f"Manifest parent does not exist: {parent}")
    if os.path.lexists(manifest_path):
        manifest_stat = os.lstat(manifest_path)
        if not stat.S_ISREG(manifest_stat.st_mode):
            raise SystemExit(f"Manifest destination is not a regular file: {manifest_path}")
    return manifest_path


def reject_manifest_mapping_overlap(manifest, target_root, mappings):
    manifest_path = os.path.abspath(manifest)
    root = os.path.abspath(target_root)
    for mapping in mappings:
        mapped_root = os.path.join(root, *mapping.target.split("/"))
        if os.path.commonpath((mapped_root, manifest_path)) == mapped_root:
            raise SystemExit(
                f"Manifest path overlaps mapped target root: {mapping.target}"
            )


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def render_manifest(commit, files, payload_root):
    lines = ["source_commit\tsource_path\ttarget_path\tsha256\n"]
    for import_file in files:
        payload_path = os.path.join(payload_root, *import_file.target.split("/"))
        payload_stat = os.lstat(payload_path)
        if not stat.S_ISREG(payload_stat.st_mode):
            raise SystemExit(f"Staged payload is not a regular file: {import_file.target}")
        digest = sha256_file(payload_path)
        lines.append(
            f"{commit}\t{import_file.source}\t{import_file.target}\t{digest}\n"
        )
    return "".join(lines).encode("utf-8")


def _minimal_mapping_roots(mappings):
    roots = []
    for target in sorted(
        {mapping.target for mapping in mappings},
        key=lambda path: (len(path.split("/")), path),
    ):
        if not any(target.startswith(root + "/") for root in roots):
            roots.append(target)
    return roots


def _remove_path(path):
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path)
    elif os.path.lexists(path):
        os.unlink(path)


def _create_parents(path, created_directories):
    missing = []
    current = path
    while not os.path.exists(current):
        missing.append(current)
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
    if os.path.islink(current) or not os.path.isdir(current):
        raise OSError(f"Cannot create destination below non-directory: {current}")
    for directory in reversed(missing):
        os.mkdir(directory)
        created_directories.append(directory)


def transactional_publish(commit, mappings, files, payload_root, target_root, manifest):
    root = validate_target_paths(target_root, files, mappings)
    reject_manifest_mapping_overlap(manifest, root, mappings)
    manifest_path = validate_manifest_destination(manifest)
    manifest_content = render_manifest(commit, files, payload_root)
    mapping_roots = _minimal_mapping_roots(mappings)
    transaction_parent = os.path.dirname(root)
    if not os.path.isdir(transaction_parent):
        raise SystemExit(f"Target root parent does not exist: {transaction_parent}")

    transaction = tempfile.mkdtemp(prefix=".import-substrate-transaction.", dir=transaction_parent)
    prepared_directory = os.path.join(transaction, "prepared")
    backup_directory = os.path.join(transaction, "backups")
    os.mkdir(prepared_directory)
    os.mkdir(backup_directory)
    manifest_temp = None
    manifest_backup = None
    published = []
    created_directories = []
    try:
        for index, mapping_root in enumerate(mapping_roots):
            source = os.path.join(payload_root, *mapping_root.split("/"))
            prepared = os.path.join(prepared_directory, str(index))
            if os.path.isdir(source):
                shutil.copytree(source, prepared)
            else:
                shutil.copy2(source, prepared)

        descriptor, manifest_temp = tempfile.mkstemp(
            prefix=".import-manifest.", dir=os.path.dirname(manifest_path)
        )
        with os.fdopen(descriptor, "wb") as output:
            output.write(manifest_content)
            output.flush()
            os.fsync(output.fileno())

        # Revalidate with lstat immediately before the first target mutation.
        validate_target_paths(root, files, mappings)
        validate_manifest_destination(manifest_path)

        for index, mapping_root in enumerate(mapping_roots):
            destination = os.path.join(root, *mapping_root.split("/"))
            _create_parents(os.path.dirname(destination), created_directories)
            backup = None
            if os.path.lexists(destination):
                backup = os.path.join(backup_directory, str(index))
                os.replace(destination, backup)
            published.append((destination, backup))
            os.replace(os.path.join(prepared_directory, str(index)), destination)
            if os.environ.get("VULPRA_IMPORT_TEST_FAIL_AFTER_PUBLISH") == "1":
                raise OSError("injected failure after mapped-root publish")

        if os.path.lexists(manifest_path):
            descriptor, manifest_backup = tempfile.mkstemp(
                prefix=".import-manifest-backup.", dir=os.path.dirname(manifest_path)
            )
            os.close(descriptor)
            os.unlink(manifest_backup)
            os.replace(manifest_path, manifest_backup)
        os.replace(manifest_temp, manifest_path)
        manifest_temp = None
        if manifest_backup is not None:
            os.unlink(manifest_backup)
            manifest_backup = None
    except BaseException:
        if manifest_backup is not None:
            _remove_path(manifest_path)
            os.replace(manifest_backup, manifest_path)
            manifest_backup = None
        for destination, backup in reversed(published):
            _remove_path(destination)
            if backup is not None:
                os.replace(backup, destination)
        for directory in reversed(created_directories):
            try:
                os.rmdir(directory)
            except OSError:
                pass
        raise
    finally:
        if manifest_temp is not None and os.path.lexists(manifest_temp):
            os.unlink(manifest_temp)
        if manifest_backup is not None and os.path.lexists(manifest_backup):
            os.unlink(manifest_backup)
        shutil.rmtree(transaction)


def write_manifest(source_repo, commit, allowlist, manifest, target_root):
    mappings, files = build_import_plan(source_repo, commit, allowlist)
    root = validate_target_paths(target_root, files)
    reject_manifest_mapping_overlap(manifest, root, mappings)
    rows = []
    for import_file in files:
        target_path = os.path.join(root, *import_file.target.split("/"))
        try:
            target_stat = os.lstat(target_path)
        except FileNotFoundError as error:
            raise SystemExit(f"Missing imported target: {import_file.target}") from error
        if not stat.S_ISREG(target_stat.st_mode):
            raise SystemExit(f"Imported target is not a regular file: {import_file.target}")
        rows.append(
            (import_file.target, import_file.source, sha256_file(target_path))
        )

    manifest_path = validate_manifest_destination(manifest)
    content = ["source_commit\tsource_path\ttarget_path\tsha256\n"]
    for target_path, source_path, digest in rows:
        content.append(f"{commit}\t{source_path}\t{target_path}\t{digest}\n")
    descriptor, temporary = tempfile.mkstemp(
        prefix=".import-manifest.", dir=os.path.dirname(manifest_path)
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as output:
            output.writelines(content)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, manifest_path)
    finally:
        if os.path.lexists(temporary):
            os.unlink(temporary)


def default_target_root():
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except subprocess.CalledProcessError:
        return os.getcwd()


def main():
    parser = argparse.ArgumentParser(
        description="Generate a deterministic provenance manifest for imported files."
    )
    parser.add_argument("source_repo")
    parser.add_argument("source_sha")
    parser.add_argument("allowlist")
    parser.add_argument("manifest")
    parser.add_argument("--target-root", default=None)
    arguments = parser.parse_args()

    commit = canonical_commit(arguments.source_repo, arguments.source_sha)
    target_root = arguments.target_root or default_target_root()
    write_manifest(
        arguments.source_repo,
        commit,
        arguments.allowlist,
        arguments.manifest,
        target_root,
    )


if __name__ == "__main__":
    main()
