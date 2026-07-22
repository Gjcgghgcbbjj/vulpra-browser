#!/bin/sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
required="README.md NOTICE.md LICENSE LICENSE.firefox .github/workflows/bootstrap-core.yml docs/aegis/README.md docs/aegis/INDEX.md docs/aegis/BASELINE-GOVERNANCE.md docs/aegis/baseline/2026-07-21-initial-baseline.md docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md docs/aegis/plans/2026-07-21-vulpra-repository-bootstrap.md"
for path in $required; do
    [ -f "$root/$path" ] || { echo "missing required file: $path" >&2; exit 1; }
done

git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "repository root is not a Git worktree: $root" >&2
    exit 1
}
[ "$git_root" = "$root" ] || {
    echo "repository root is not the Git toplevel: $root (found $git_root)" >&2
    exit 1
}

[ "$(git -C "$root" rev-list --count HEAD 2>/dev/null || echo 0)" -ge 1 ] || {
    echo "repository has no initial commit" >&2
    exit 1
}

while IFS='|' read -r _date _kind indexed_path _title _rest; do
    indexed_path=$(printf '%s\n' "$indexed_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    case "$indexed_path" in
        docs/*)
            [ -f "$root/$indexed_path" ] || {
                echo "indexed workspace file does not exist: $indexed_path" >&2
                exit 1
            }
            ;;
    esac
done < "$root/docs/aegis/INDEX.md"

baseline="$root/docs/aegis/baseline/2026-07-21-initial-baseline.md"
grep -Fqx 'Status: `substrate-import-verified`' "$baseline" || {
    echo 'baseline status is not substrate-import-verified' >&2
    exit 1
}
grep -Fq '| provenance | docs/provenance/substrate-boundary.md |' \
    "$root/docs/aegis/INDEX.md" || {
    echo 'substrate boundary is not indexed' >&2
    exit 1
}

workflow="$root/.github/workflows/bootstrap-core.yml"
grep -Fq 'fetch-depth: 0' "$workflow" || {
    echo 'bootstrap workflow must fetch history for pinned substrate baseline verification' >&2
    exit 1
}
for command in \
    './Tests/Bootstrap/test-repository-shape.sh' \
    './Tests/Bootstrap/test-repository-shape-nested-parent.sh' \
    './Tests/Bootstrap/test-import-boundary.sh' \
    './Tests/Bootstrap/test-gecko-substrate.sh' \
    './Tests/Bootstrap/test-active-identity.sh' \
    './Tests/Bootstrap/test-jit-substrate.sh' \
    './Tests/RuntimeShell/run-portable.sh' \
    './Tests/Browser/run-portable.sh' \
    './Tools/Gecko/test-gecko-artifact.sh' \
    "find Tools Tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n" \
    'git diff --check'
do
    grep -Fq -- "$command" "$workflow" || {
        echo "bootstrap workflow is missing portable command: $command" >&2
        exit 1
    }
done

echo "Repository shape checks passed."
