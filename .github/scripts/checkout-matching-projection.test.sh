#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname "$0")" && pwd)
checkout_script="$script_dir/checkout-matching-projection.sh"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/matching-projection-test.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

remote="$scratch/deixic-node.git"
seed="$scratch/seed"
git init -q --bare "$remote"
git init -q -b main "$seed"
git -C "$seed" config user.name 'Projection validation test'
git -C "$seed" config user.email 'projection-validation@example.invalid'

write_receipt() {
  local source_sha=$1
  cat > "$seed/.repository-projection.json" <<EOF
{
  "projection": "deixic-node",
  "sourceRepository": "dx-corp/mono",
  "destinationRepository": "dx-corp/deixic-node",
  "sourceSha": "$source_sha"
}
EOF
}

old_source=1111111111111111111111111111111111111111
matching_source=2222222222222222222222222222222222222222
write_receipt "$old_source"
git -C "$seed" add .repository-projection.json
git -C "$seed" commit -q -m 'old main projection'
git -C "$seed" remote add origin "$remote"
git -C "$seed" push -q -u origin main

git -C "$seed" switch -q -c sync/mono-projection
write_receipt "$matching_source"
git -C "$seed" add .repository-projection.json
git -C "$seed" commit -q -m 'matching projection branch'
matching_commit=$(git -C "$seed" rev-parse HEAD)
git -C "$seed" push -q -u origin sync/mono-projection

matched="$scratch/matched"
MATCHING_PROJECTION_ATTEMPTS=1 MATCHING_PROJECTION_DELAY_SECONDS=0 \
  bash "$checkout_script" "$remote" deixic-node "$matching_source" "$matched"
test "$(git -C "$matched" rev-parse HEAD)" = "$matching_commit"

missing="$scratch/missing"
if MATCHING_PROJECTION_ATTEMPTS=1 MATCHING_PROJECTION_DELAY_SECONDS=0 \
  bash "$checkout_script" "$remote" deixic-node 3333333333333333333333333333333333333333 "$missing" \
  >"$scratch/missing-output" 2>"$scratch/missing-error"; then
  printf 'A mismatched projection unexpectedly passed.\n' >&2
  exit 1
fi
grep -F 'No deixic-node projection matched Mono source' "$scratch/missing-error" >/dev/null

printf 'Matching projection checkout tests passed.\n'
