#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  printf 'Usage: %s <repository-url> <projection> <source-sha> <destination>\n' "$0" >&2
  exit 2
fi

repository_url=$1
projection=$2
source_sha=$3
destination=$4
attempts=${MATCHING_PROJECTION_ATTEMPTS:-40}
delay_seconds=${MATCHING_PROJECTION_DELAY_SECONDS:-15}

if [[ ! "$projection" =~ ^[a-z0-9-]+$ ]]; then
  printf 'Invalid projection name: %s\n' "$projection" >&2
  exit 2
fi
if [[ ! "$source_sha" =~ ^[0-9a-f]{40}$ ]]; then
  printf 'Invalid projection source SHA: %s\n' "$source_sha" >&2
  exit 2
fi
if [[ ! "$attempts" =~ ^[1-9][0-9]*$ || ! "$delay_seconds" =~ ^[0-9]+$ ]]; then
  printf 'Projection retry settings must be non-negative integers with at least one attempt.\n' >&2
  exit 2
fi
if [[ -e "$destination" ]]; then
  printf 'Projection checkout destination already exists: %s\n' "$destination" >&2
  exit 2
fi

git clone --filter=blob:none --no-checkout "$repository_url" "$destination"

receipt_matches() {
  local ref=$1
  git -C "$destination" show "$ref:.repository-projection.json" 2>/dev/null |
    node -e '
      const fs = require("node:fs");
      const [projection, sourceSha] = process.argv.slice(1);
      let receipt;
      try {
        receipt = JSON.parse(fs.readFileSync(0, "utf8"));
      } catch {
        process.exit(1);
      }
      const matches =
        receipt.projection === projection &&
        receipt.sourceRepository === "dx-corp/mono" &&
        receipt.destinationRepository === `dx-corp/${projection}` &&
        receipt.sourceSha === sourceSha;
      process.exit(matches ? 0 : 1);
    ' "$projection" "$source_sha"
}

for ((attempt = 1; attempt <= attempts; attempt += 1)); do
  git -C "$destination" fetch --quiet --prune --depth=1 origin \
    '+refs/heads/*:refs/remotes/origin/*'

  while IFS= read -r ref; do
    [[ "$ref" == 'refs/remotes/origin/HEAD' ]] && continue
    if receipt_matches "$ref"; then
      git -C "$destination" checkout --quiet --detach "$ref"
      printf 'Checked out %s at %s for Mono source %s.\n' \
        "$ref" "$(git -C "$destination" rev-parse HEAD)" "$source_sha"
      exit 0
    fi
  done < <(
    {
      printf 'refs/remotes/origin/sync/mono-projection\n'
      git -C "$destination" for-each-ref --format='%(refname)' refs/remotes/origin
    } | awk '!seen[$0]++'
  )

  if ((attempt < attempts)); then
    printf 'No matching %s projection yet for %s; retrying (%d/%d).\n' \
      "$projection" "$source_sha" "$attempt" "$attempts"
    sleep "$delay_seconds"
  fi
done

printf 'No %s projection matched Mono source %s after %d attempts.\n' \
  "$projection" "$source_sha" "$attempts" >&2
exit 1
