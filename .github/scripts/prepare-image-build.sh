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
source "$script_dir/helpers.sh"

require_env REGISTRY
require_env IMAGE_NAME
require_env ARCHITECTURES
require_env VERSION
require_env ENGINE_COMMIT_HASH
require_env COMBINED_COMMIT_HASHES_TAG
require_env OCI_ANNOTATION_AUTHORS
require_env OCI_ANNOTATION_URL
require_env OCI_ANNOTATION_DOCUMENTATION
require_env OCI_ANNOTATION_SOURCE
require_env OCI_ANNOTATION_VENDOR
require_env OCI_ANNOTATION_LICENSES
require_env OCI_ANNOTATION_TITLE
require_env OCI_ANNOTATION_DESCRIPTION
require_env OCI_ANNOTATION_BASE_NAME

image="$REGISTRY/$IMAGE_NAME"
timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
architectures="$(trim "$ARCHITECTURES")"

declare -a tags=()
declare -a prefixes=()
declare -a metadata_entries=()
declare -a label_lines=()
declare -a annotation_lines=()

platforms=""
needs_qemu="false"
ref_name="$image:$COMBINED_COMMIT_HASHES_TAG"

case "$architectures" in
  both|"Both x86_64 and aarch64")
    platforms="linux/amd64,linux/arm64"
    needs_qemu="true"
    prefixes=("manifest" "index")
    ;;
  amd64|"x86_64 only")
    platforms="linux/amd64"
    needs_qemu="false"
    prefixes=("manifest")
    ;;
  arm64|"aarch64 only")
    platforms="linux/arm64"
    needs_qemu="true"
    prefixes=("manifest")
    ;;
  *)
    fail "Unsupported architectures value '$architectures'"
    ;;
esac

if [[ "$VERSION" == "254" ]]; then
  tags+=("$image:latest")
fi

tags+=(
  "$image:$VERSION"
  "$image:$COMBINED_COMMIT_HASHES_TAG"
)

metadata_entries=(
  "created=$timestamp"
  "authors=$OCI_ANNOTATION_AUTHORS"
  "url=$OCI_ANNOTATION_URL"
  "documentation=$OCI_ANNOTATION_DOCUMENTATION"
  "source=$OCI_ANNOTATION_SOURCE"
  "version=$VERSION"
  "revision=$ENGINE_COMMIT_HASH"
  "vendor=$OCI_ANNOTATION_VENDOR"
  "licenses=$OCI_ANNOTATION_LICENSES"
  "ref.name=$ref_name"
  "title=$OCI_ANNOTATION_TITLE"
  "description=$OCI_ANNOTATION_DESCRIPTION"
  "base.name=$OCI_ANNOTATION_BASE_NAME"
)

for entry in "${metadata_entries[@]}"; do
  key="${entry%%=*}"
  value="${entry#*=}"

  label_lines+=("org.opencontainers.image.$key=$value")

  for prefix in "${prefixes[@]}"; do
    annotation_lines+=("$prefix:org.opencontainers.image.$key=$value")
  done
done

printf -v tags_output '%s,' "${tags[@]}"
tags_output="${tags_output%,}"

printf -v annotations_output '%s\n' "${annotation_lines[@]}"
annotations_output="${annotations_output%$'\n'}"

printf -v labels_output '%s\n' "${label_lines[@]}"
labels_output="${labels_output%$'\n'}"

write_output platforms "$platforms"
write_output needs_qemu "$needs_qemu"
write_output tags "$tags_output"
write_multiline_output annotations "$annotations_output"
write_multiline_output labels "$labels_output"
