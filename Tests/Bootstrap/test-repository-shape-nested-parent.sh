#!/bin/sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
fixture="$(mktemp -d "$repo_root/.repository-shape-nested-parent.XXXXXX")"

cleanup() {
    find "$fixture" -type f -exec rm -f {} \; 2>/dev/null || :
    find "$fixture" -depth -type d -exec rmdir {} \; 2>/dev/null || :
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$fixture/Tests/Bootstrap"
cp "$repo_root/Tests/Bootstrap/test-repository-shape.sh" "$fixture/Tests/Bootstrap/"

required="README.md NOTICE.md LICENSE LICENSE.firefox .github/workflows/bootstrap-core.yml Tests/RuntimeShell/run-portable.sh docs/aegis/README.md docs/aegis/INDEX.md docs/aegis/BASELINE-GOVERNANCE.md docs/aegis/baseline/2026-07-21-initial-baseline.md docs/aegis/baseline/2026-07-22-runtime-shell-portable-baseline.md docs/aegis/specs/2026-07-21-vulpra-core-substrate-repository-design.md docs/aegis/plans/2026-07-21-vulpra-repository-bootstrap.md"
for path in $required; do
    mkdir -p "$fixture/$(dirname -- "$path")"
    : > "$fixture/$path"
done

[ ! -e "$fixture/.git" ] || {
    echo "nested fixture unexpectedly contains .git" >&2
    exit 1
}

if output=$(sh "$fixture/Tests/Bootstrap/test-repository-shape.sh" 2>&1); then
    echo "nested fixture without its own .git unexpectedly passed" >&2
    exit 1
fi

case "$output" in
    *"repository root is not the Git toplevel:"*) ;;
    *)
        printf '%s\n' "$output" >&2
        echo "nested fixture failed for an unexpected reason" >&2
        exit 1
        ;;
esac

echo "Nested parent repository regression check passed."
