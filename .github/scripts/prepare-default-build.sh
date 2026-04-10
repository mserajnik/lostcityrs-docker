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
# shellcheck source=.github/scripts/helpers.sh
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env GITHUB_EVENT_NAME
require_env PACKAGE_OWNER
require_env PACKAGE_NAME
require_env ENGINE_REPOSITORY_OWNER
require_env ENGINE_REPOSITORY_NAME
require_env ENGINE_REPOSITORY_REF
require_env CONTENT_REPOSITORY_OWNER
require_env CONTENT_REPOSITORY_NAME
require_env CONTENT_REPOSITORY_REF
require_env VERSION

force_rebuild="${FORCE_REBUILD:-false}"
images_already_exist="false"

engine_commit_hash="$(gh api "/repos/$ENGINE_REPOSITORY_OWNER/$ENGINE_REPOSITORY_NAME/commits/$ENGINE_REPOSITORY_REF" --jq '.sha')"
content_commit_hash="$(gh api "/repos/$CONTENT_REPOSITORY_OWNER/$CONTENT_REPOSITORY_NAME/commits/$CONTENT_REPOSITORY_REF" --jq '.sha')"
combined_commit_hashes_tag="$VERSION-engine.${engine_commit_hash:0:7}-content.${content_commit_hash:0:7}"

if [[ "$GITHUB_EVENT_NAME" == "schedule" && "$(date +%u)" -eq 1 ]]; then
  images_already_exist="false"
elif [[ "$force_rebuild" == "true" ]]; then
  images_already_exist="false"
else
  # shellcheck disable=SC2153
  package_endpoint="$(package_versions_endpoint "$PACKAGE_OWNER" "$PACKAGE_NAME")"
  set +e
  existing_tags="$(gh api --paginate "$package_endpoint?per_page=100" --jq '.[].metadata.container.tags[]?' 2>&1)"
  gh_status=$?
  set -e

  if [[ $gh_status -ne 0 ]]; then
    if grep -Fq "HTTP 404" <<< "$existing_tags"; then
      existing_tags=""
    else
      printf '%s\n' "$existing_tags" >&2
      fail "Failed to query package versions for '$PACKAGE_OWNER/$PACKAGE_NAME'"
    fi
  fi

  if grep -Fxq "$combined_commit_hashes_tag" <<< "$existing_tags"; then
    images_already_exist="true"
  fi
fi

write_output engine_commit_hash "$engine_commit_hash"
write_output content_commit_hash "$content_commit_hash"
write_output combined_commit_hashes_tag "$combined_commit_hashes_tag"
write_output images_already_exist "$images_already_exist"
