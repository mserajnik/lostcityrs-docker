#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Resolves the current upstream Lost City RS commits for each version (engine
# and content) and decides whether the default workflow should build images
# this run (skipping when images for those commits already exist, unless the
# run is a scheduled Monday rebuild or a manual force rebuild).

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
  combined_revision_tag="$version"
  combined_revision_tag+="-engine.${engine_commit_hash:0:7}"
  combined_revision_tag+="-content.${content_commit_hash:0:7}"

  images_already_exist="false"

  if [[ "$schedule_force_build" != "true" && "$force_rebuild" != "true" ]]; then
    if grep -Fxq "$combined_revision_tag" <<<"$existing_tags"; then
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
    --arg combined_revision_tag "$combined_revision_tag" \
    --arg images_already_exist "$images_already_exist" \
    '. + {
       ($version): {
         engine_commit_hash: $engine_commit_hash,
         content_commit_hash: $content_commit_hash,
         combined_revision_tag: $combined_revision_tag,
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
