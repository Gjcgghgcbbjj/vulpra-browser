#!/bin/sh
set -eu

[ "$#" -eq 2 ] || {
  echo "usage: $0 <producer-contract> <destination>" >&2
  exit 64
}

CONTRACT=$1
DESTINATION=$2
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)

python3 "$ROOT/Tools/GeckoProducer/verify-producer.py" --contract "$CONTRACT"
[ ! -e "$DESTINATION" ] || {
  echo "gecko-fetch-error: destination already exists: $DESTINATION" >&2
  exit 1
}

read_contract_field() {
  python3 - "$CONTRACT" "$1" <<'PY'
import json
import sys

value = json.load(open(sys.argv[1], encoding="utf-8"))["upstream"][sys.argv[2]]
print(value)
PY
}

REPOSITORY=$(read_contract_field repository)
COMMIT=$(read_contract_field commit)

mkdir -p "$(dirname -- "$DESTINATION")"
git init "$DESTINATION"
git -C "$DESTINATION" remote add origin "$REPOSITORY"
git -C "$DESTINATION" fetch --depth=1 origin "$COMMIT"
git -C "$DESTINATION" checkout --detach FETCH_HEAD

ACTUAL=$(git -C "$DESTINATION" rev-parse HEAD)
[ "$ACTUAL" = "$COMMIT" ] || {
  echo "gecko-fetch-error: expected $COMMIT, got $ACTUAL" >&2
  exit 1
}
[ -z "$(git -C "$DESTINATION" status --porcelain)" ] || {
  echo "gecko-fetch-error: detached checkout is dirty" >&2
  exit 1
}

printf 'PASS: fetched Gecko source %s\n' "$ACTUAL"
