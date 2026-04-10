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
# shellcheck disable=SC2153
architectures="$(trim "$ARCHITECTURES")"

declare -a tags=()
declare -a metadata_entries=()
declare -a label_lines=()
declare -a manifest_annotation_lines=()
declare -a index_annotation_lines=()
declare -a build_args=()

build_amd64="false"
build_arm64="false"
is_multi_arch="false"
ref_name="$image:$COMBINED_COMMIT_HASHES_TAG"
dockerfile="./Dockerfile"

case "$architectures" in
  both|"Both amd64 and arm64")
    build_amd64="true"
    build_arm64="true"
    is_multi_arch="true"
    ;;
  amd64|"amd64 only")
    build_amd64="true"
    ;;
  arm64|"arm64 only")
    build_arm64="true"
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

build_args+=("LOST_CITY_RS_VERSION=$VERSION")

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
  manifest_annotation_lines+=("manifest:org.opencontainers.image.$key=$value")

  if [[ "$is_multi_arch" == "true" ]]; then
    index_annotation_lines+=("index:org.opencontainers.image.$key=$value")
  fi
done

printf -v tags_output '%s,' "${tags[@]}"
tags_output="${tags_output%,}"

printf -v manifest_annotations_output '%s\n' "${manifest_annotation_lines[@]}"
manifest_annotations_output="${manifest_annotations_output%$'\n'}"

if ((${#index_annotation_lines[@]} > 0)); then
  printf -v index_annotations_output '%s\n' "${index_annotation_lines[@]}"
  index_annotations_output="${index_annotations_output%$'\n'}"
else
  index_annotations_output=""
fi

printf -v labels_output '%s\n' "${label_lines[@]}"
labels_output="${labels_output%$'\n'}"

printf -v build_args_output '%s\n' "${build_args[@]}"
build_args_output="${build_args_output%$'\n'}"

write_output image "$image"
write_output package_name "${IMAGE_NAME##*/}"
write_output dockerfile "$dockerfile"
write_output build_amd64 "$build_amd64"
write_output build_arm64 "$build_arm64"
write_output is_multi_arch "$is_multi_arch"
write_output tags "$tags_output"
write_multiline_output build_args "$build_args_output"
write_multiline_output manifest_annotations "$manifest_annotations_output"
write_multiline_output index_annotations "$index_annotations_output"
write_multiline_output labels "$labels_output"
