#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Builds the `ignore-versions` regex for `actions/delete-package-versions` so
# the recency-based pruning never removes a package version that still carries
# a moving tag. Because the moving tags share one package, a dormant tag's
# version could otherwise age out and be deleted; here every version whose tags
# include one of `PROTECTED_TAGS` is collected and anchored into a regex
# matching its digest (the version name the action matches against). A moving
# tag lives on the multi-arch index manifest, whose per-arch child manifests
# are untagged and not returned by the packages API; those would still be
# pruned and leave the index unpullable, so each protected index's children are
# resolved from the registry and protected as well. Prints `^$` (matches
# nothing) when no version is protected.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env PACKAGE_OWNER
require_env PACKAGE_NAME
require_env PROTECTED_TAGS

# Fetches a GHCR pull token for the package, used for the registry manifest
# lookups that resolve an index's child manifests (the packages API does not
# expose that relationship).
registry_pull_token() {
  # shellcheck disable=SC2153
  curl --fail --silent --show-error \
    --user "$PACKAGE_OWNER:$GH_TOKEN" \
    "https://ghcr.io/token?scope=repository:$PACKAGE_OWNER/$PACKAGE_NAME:pull" |
    jq -r '.token'
}

# Prints the child manifest digests of an index manifest, or nothing for a
# single-arch image (which has no children).
child_manifest_digests() {
  local token="$1"
  local digest="$2"

  # shellcheck disable=SC2153
  curl --fail --silent --show-error \
    --header "Authorization: Bearer $token" \
    --header "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json" \
    "https://ghcr.io/v2/$PACKAGE_OWNER/$PACKAGE_NAME/manifests/$digest" |
    jq -r '.manifests[]?.digest // empty'
}

protected_json="$(jq -cR 'split(",") | map(select(. != ""))' <<<"$PROTECTED_TAGS")"

# shellcheck disable=SC2153
package_endpoint="$(package_versions_endpoint "$PACKAGE_OWNER" "$PACKAGE_NAME")"
package_versions_json="$(gh api --paginate --slurp "$package_endpoint?per_page=100")"

mapfile -t index_digests < <(
  jq -r \
    --argjson protected "$protected_json" \
    '.[][]
     | . as $version
     | (($version.metadata.container.tags // [])) as $tags
     | select($protected | any(. as $tag | $tags | index($tag) != null))
     | $version.name' \
    <<<"$package_versions_json"
)

declare -a protected_digests=("${index_digests[@]}")

if ((${#index_digests[@]} > 0)); then
  registry_token="$(registry_pull_token)"
  for index_digest in "${index_digests[@]}"; do
    children="$(child_manifest_digests "$registry_token" "$index_digest")"
    while IFS= read -r child_digest; do
      if [[ -n "$child_digest" ]]; then
        protected_digests+=("$child_digest")
      fi
    done <<<"$children"
  done
fi

if ((${#protected_digests[@]} == 0)); then
  regex='^$'
else
  joined="$(printf '%s\n' "${protected_digests[@]}" | sort -u | paste -sd '|' -)"
  regex="^(${joined})$"
fi

echo "Protected package versions: ${#protected_digests[@]} (${#index_digests[@]} tagged)"
write_output ignore_versions_regex "$regex"
