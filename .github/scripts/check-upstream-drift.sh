#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Compares pinned upstream references against the resolved upstream `HEAD` of
# each supported version's engine branch. Every supported version is a separate
# branch of the same engine repository, so the checks run once per version,
# driven by the pinned commit map. Fails the workflow when any watched file,
# the SQLite migration set, or the runtime indicator has drifted so the
# matching local setup can be reviewed.
#
# Three surfaces are covered per version:
# - The configuration loader (`src/util/Environment.ts` on the Bun versions,
#   `src/util/WorldConfig.ts` on the Node versions): the authoritative
#   environment variable surface, so added or removed variables and changed
#   defaults that would silently alter behavior show up.
# - `.gitignore`: surfaces changes to persisted paths (the SQLite database
#   filenames and the player save directory are listed here), so a renamed
#   database file or a new persistent data directory is caught.
# - The SQLite migration set (`prisma/singleworld/migrations`): additions,
#   changes, removals, or a wholesale layout rewrite, any of which can break
#   `prisma migrate deploy` against a database that has already been migrated.
#
# Additionally, the Bun versions carry a tripwire for a switch to Node: a
# `package-lock.json` must not appear upstream, because its presence is the
# artifact of upstream switching the branch from Bun to Node (which would
# require building it from `Dockerfile.node` instead of `Dockerfile`).

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
source "$script_dir/helpers.sh"

require_env GH_TOKEN
require_env ENGINE_REPOSITORY
require_env BUILD_METADATA
require_env DRIFT_KNOWN_COMMITS

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# shellcheck disable=SC2153
engine_repository="$(trim "$ENGINE_REPOSITORY")"

# Each entry: <description>|<known_url>|<latest_url>.
declare -a checks=()
# Each entry: <description>|<latest_url>.
declare -a absent_checks=()
# Each entry: <version>|<known_commit_hash>|<latest_commit_hash>.
declare -a migration_checks=()

add_github_check() {
  local version="$1"
  local known_commit_hash="$2"
  local latest_commit_hash="$3"
  local path="$4"

  local desc="$version:$path"
  local known_url="https://raw.githubusercontent.com/$engine_repository/$known_commit_hash/$path"
  local latest_url="https://raw.githubusercontent.com/$engine_repository/$latest_commit_hash/$path"

  checks+=("$desc|$known_url|$latest_url")
}

add_absent_check() {
  local version="$1"
  local latest_commit_hash="$2"
  local path="$3"

  local desc="$version:$path"
  local latest_url="https://raw.githubusercontent.com/$engine_repository/$latest_commit_hash/$path"

  absent_checks+=("$desc|$latest_url")
}

migration_manifest() {
  local commit_hash="$1"

  gh api "/repos/$engine_repository/git/trees/$commit_hash?recursive=1" |
    jq -r '.tree[]
      | select(.type == "blob"
        and (.path | startswith("prisma/singleworld/migrations/")))
      | "\(.path) \(.sha)"' |
    sort
}

# The versions to check are taken from the build metadata (every version that
# gets built), not from the pinned commit map, so that a version which is built
# but has no pin fails loudly below instead of going silently unchecked.
mapfile -t versions < <(jq -r 'keys[]' <<<"$BUILD_METADATA")

if ((${#versions[@]} == 0)); then
  fail "No versions found in BUILD_METADATA."
fi

for version in "${versions[@]}"; do
  known_commit_hash="$(jq -r --arg v "$version" '.[$v] // empty' \
    <<<"$DRIFT_KNOWN_COMMITS")"
  latest_commit_hash="$(jq -r --arg v "$version" '.[$v].engine_commit_hash // empty' \
    <<<"$BUILD_METADATA")"

  if [[ -z "$known_commit_hash" ]]; then
    fail "No known commit pinned for version '$version' in DRIFT_KNOWN_COMMITS."
  fi
  if [[ -z "$latest_commit_hash" ]]; then
    fail "No resolved latest commit for version '$version' in BUILD_METADATA."
  fi

  add_github_check "$version" \
    "$known_commit_hash" "$latest_commit_hash" .gitignore

  if [[ "$version" == "274" ]]; then
    add_github_check "$version" \
      "$known_commit_hash" "$latest_commit_hash" src/util/WorldConfig.ts
  else
    add_github_check "$version" \
      "$known_commit_hash" "$latest_commit_hash" src/util/Environment.ts
    add_absent_check "$version" "$latest_commit_hash" package-lock.json
  fi

  migration_checks+=("$version|$known_commit_hash|$latest_commit_hash")
done

failures=0

for check in "${checks[@]}"; do
  IFS='|' read -r desc known_url latest_url <<<"$check"

  curl --fail --silent --show-error --location \
    --output "$workdir/known" "$known_url"
  curl --fail --silent --show-error --location \
    --output "$workdir/latest" "$latest_url"

  if ! diff -u "$workdir/known" "$workdir/latest" >/dev/null; then
    printf '\n=== DRIFT DETECTED: %s ===\n' "$desc"
    diff -u "$workdir/known" "$workdir/latest" || true
    failures=$((failures + 1))
  else
    printf 'OK: %s\n' "$desc"
  fi
done

for check in "${absent_checks[@]}"; do
  IFS='|' read -r desc latest_url <<<"$check"

  status="$(curl --silent --show-error --location \
    --output /dev/null --write-out '%{http_code}' "$latest_url")"

  if [[ "$status" == "200" ]]; then
    printf '\n=== DRIFT DETECTED: %s (now present upstream) ===\n' "$desc"
    failures=$((failures + 1))
  elif [[ "$status" == "404" ]]; then
    printf 'OK: %s (absent)\n' "$desc"
  else
    fail "Unexpected HTTP status $status for $latest_url."
  fi
done

for check in "${migration_checks[@]}"; do
  IFS='|' read -r version known_commit_hash latest_commit_hash <<<"$check"

  migration_manifest "$known_commit_hash" >"$workdir/known"
  migration_manifest "$latest_commit_hash" >"$workdir/latest"

  if ! diff -u "$workdir/known" "$workdir/latest" >/dev/null; then
    printf '\n=== DRIFT DETECTED: %s:prisma/singleworld/migrations ===\n' "$version"
    diff -u "$workdir/known" "$workdir/latest" || true
    failures=$((failures + 1))
  else
    printf 'OK: %s:prisma/singleworld/migrations\n' "$version"
  fi
done

if ((failures > 0)); then
  printf '\n%s upstream reference(s) drifted from the pinned revision.\n' "$failures" >&2
  fail "Review the diff(s) above, refresh any local files that need to align, and bump the matching version in DRIFT_KNOWN_COMMITS."
fi
