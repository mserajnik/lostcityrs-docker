#!/usr/bin/env bash

# lostcityrs-docker
# Copyright (C) 2025-2026  Michael Serajnik  https://github.com/mserajnik

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env GITHUB_EVENT_NAME
require_env PACKAGE_OWNER
require_env PACKAGE_NAME
require_env ENGINE_REPOSITORY_OWNER
require_env ENGINE_REPOSITORY_NAME
require_env CONTENT_REPOSITORY_OWNER
require_env CONTENT_REPOSITORY_NAME
require_env VERSIONS

force_rebuild="${FORCE_REBUILD:-false}"
schedule_force_build="false"

if [[ "$GITHUB_EVENT_NAME" == "schedule" && "$(date +%u)" -eq 1 ]]; then
  schedule_force_build="true"
fi

resolve_commit_hash() {
  local repository_owner="$1"
  local repository_name="$2"
  local repository_ref="$3"

  gh api "/repos/$repository_owner/$repository_name/commits/$repository_ref" \
    --jq '.sha'
}

existing_tags_for_package() {
  local package_owner="$1"
  local package_name="$2"
  local endpoint
  local tags
  local status

  endpoint="$(package_versions_endpoint "$package_owner" "$package_name")"

  set +e
  tags="$(gh api --paginate "$endpoint?per_page=100" \
    --jq '.[].metadata.container.tags[]?' 2>&1)"
  status=$?
  set -e

  if [[ $status -ne 0 ]]; then
    if grep -Fq "HTTP 404" <<<"$tags"; then
      printf '%s' ""
      return 0
    fi

    printf '%s\n' "$tags" >&2
    fail "Failed to query package versions for '$package_owner/$package_name'."
  fi

  printf '%s' "$tags"
}

# shellcheck disable=SC2153
mapfile -t versions < <(jq -r '.[]' <<<"$VERSIONS")

# The package is shared across all versions, so we query its tags once and
# reuse the result for each version's existence check.
# shellcheck disable=SC2153
existing_tags="$(existing_tags_for_package "$PACKAGE_OWNER" "$PACKAGE_NAME")"

build_metadata="{}"
declare -a versions_to_build=()
any_images_to_build="false"

for version in "${versions[@]}"; do
  engine_commit_hash="$(resolve_commit_hash \
    "$ENGINE_REPOSITORY_OWNER" "$ENGINE_REPOSITORY_NAME" "$version")"
  content_commit_hash="$(resolve_commit_hash \
    "$CONTENT_REPOSITORY_OWNER" "$CONTENT_REPOSITORY_NAME" "$version")"
  combined_commit_hashes_tag="$version"
  combined_commit_hashes_tag+="-engine.${engine_commit_hash:0:7}"
  combined_commit_hashes_tag+="-content.${content_commit_hash:0:7}"

  images_already_exist="false"

  if [[ "$schedule_force_build" != "true" && "$force_rebuild" != "true" ]]; then
    if grep -Fxq "$combined_commit_hashes_tag" <<<"$existing_tags"; then
      images_already_exist="true"
    fi
  fi

  if [[ "$images_already_exist" != "true" ]]; then
    any_images_to_build="true"
    versions_to_build+=("$version")
  fi

  build_metadata="$(jq \
    --arg version "$version" \
    --arg engine_commit_hash "$engine_commit_hash" \
    --arg content_commit_hash "$content_commit_hash" \
    --arg combined_commit_hashes_tag "$combined_commit_hashes_tag" \
    --arg images_already_exist "$images_already_exist" \
    '. + {
       ($version): {
         engine_commit_hash: $engine_commit_hash,
         content_commit_hash: $content_commit_hash,
         combined_commit_hashes_tag: $combined_commit_hashes_tag,
         images_already_exist: $images_already_exist
       }
     }' <<<"$build_metadata")"
done

if ((${#versions_to_build[@]} > 0)); then
  versions_to_build_json="$(printf '%s\n' "${versions_to_build[@]}" | jq -R . | jq -s -c .)"
else
  versions_to_build_json="[]"
fi

write_output build_metadata "$(jq -c '.' <<<"$build_metadata")"
write_output versions_to_build "$versions_to_build_json"
write_output any_images_to_build "$any_images_to_build"
