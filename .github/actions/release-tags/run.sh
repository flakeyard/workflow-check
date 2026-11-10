#!/usr/bin/env bash
# Fails unless, at commit SHA, every preset in an extends of renovate.json and
# every template of a .copier-answers*.yml at the root is pinned to a tag
# vX.Y.Z of a GitHub release that is immutable. Sources in ALLOW_UNPINNED are
# not checked; built-in presets of Renovate are versioned with Renovate.
# Owners, repositories and tags are validated before they are used in an API
# path. ENABLED=false switches the check off.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
# Ranges such as [a-z] match only ASCII, whatever the locale of the runner.
export LC_ALL=C.UTF-8
: "${SHELL_LIB:?}" "${REPO:?}" "${SHA:?}" "${ENABLED:?}" "${ALLOW_UNPINNED?}"
lib=$(dirname "$0")/../lib
# shellcheck source=/dev/null
source "$SHELL_LIB/github/api.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/github/contents.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/github/forms.sh"
# shellcheck source=../lib/renovate.sh
source "$lib/renovate.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

readonly CONFIG=renovate.json
readonly ANSWERS_FILE='^\.copier-answers.*\.yml$'
readonly RELEASE_TAG='^v[0-9]+\.[0-9]+\.[0-9]+$'
# A template on GitHub, as Copier writes it to _src_path.
readonly GITHUB_TEMPLATE='^(gh:|https://github\.com/)([^/]+/[^/]+)$'

check_allow_input() {
  is_repository_list "$ALLOW_UNPINNED" || fail "allow-unpinned is not a JSON array of owner/repo"
}

# is_allowed REPOSITORY: REPOSITORY is in ALLOW_UNPINNED, without case.
is_allowed() {
  lists_repository "$ALLOW_UNPINNED" "$1"
}

# check_release WHAT REPOSITORY TAG: the release TAG of REPOSITORY exists and
# is immutable.
check_release() {
  local what=$1 repository=$2 tag=$3 release status=0
  release=$(api_request GET "repos/$repository/releases/tags/$tag" 2>/dev/null) || status=$?
  if ((status == NOT_FOUND)); then
    problem "$what: $repository has no release $tag that GITHUB_TOKEN can read"
  elif ((status != 0)); then
    fail "cannot read the release $tag of $repository"
  elif ! jq -e '.immutable == true' <<<"$release" >/dev/null; then
    problem "$what: the release $tag of $repository is not immutable"
  else
    summary "| $(code_span "$what") | $(code_span "$repository $tag") |"
  fi
}

# check_reference WHAT REPOSITORY TAG: WHAT, from REPOSITORY, is pinned to an
# immutable release TAG, unless REPOSITORY is allowed to be unpinned.
check_reference() {
  local what=$1 repository=$2 tag=$3
  if [[ ! $repository =~ $REPOSITORY_FORM ]]; then
    problem "$what: not a GitHub repository: $repository"
  elif is_allowed "$repository"; then
    notice "$what: $repository may be unpinned"
  elif [[ ! $tag =~ $RELEASE_TAG ]]; then
    problem "$what: not pinned to a release tag vX.Y.Z"
  else
    check_release "$what" "$repository" "$tag"
  fi
}

# check_preset PRESET: a preset of renovate.json is pinned.
check_preset() {
  local preset=$1 what="preset $1" repository
  is_builtin_preset "$preset" && return 0
  if ! repository=$(preset_source "$preset"); then
    problem "$what: not a preset of a repository"
  elif ! is_github_preset "$preset" && ! is_allowed "$repository"; then
    problem "$what: only presets of GitHub repositories, github>owner/repo#vX.Y.Z, can be pinned to a release"
  else
    check_reference "$what" "$repository" "$(preset_tag "$preset")"
  fi
}

# The presets of every extends of a configuration, anywhere in it.
readonly EXTENDS='[.. | objects | .extends? // empty]'

# check_presets: every preset of renovate.json is pinned; nothing to check
# without renovate.json.
check_presets() {
  local config status=0 preset
  config=$(file_at "$CONFIG" "$SHA" 2>/dev/null) || status=$?
  ((status != NOT_FOUND)) || return 0
  ((status == 0)) || fail "cannot read $CONFIG at $SHA"
  jq -e "$PRESET_LIST_DEF $EXTENDS | all(preset_list)" <<<"$config" >/dev/null 2>&1 \
    || fail "$CONFIG is not JSON whose extends are arrays of one-line strings"
  while IFS= read -r preset; do
    check_preset "$preset"
  done < <(jq -r "$EXTENDS"' | .[][]' <<<"$config")
}

# answer KEY ANSWERS: print the value of KEY in the Copier answers ANSWERS.
answer() {
  local key=$1 answers=$2 line value
  while IFS= read -r line; do
    [[ $line =~ ^$key:[[:space:]]*(.*)$ ]] || continue
    value=${BASH_REMATCH[1]}
    value=${value#[\"\']}
    printf '%s\n' "${value%[\"\']}"
    return 0
  done <<<"$answers"
}

# check_template FILE: the template of the Copier answers FILE is pinned.
check_template() {
  local file=$1 what="template of $1" answers source
  answers=$(file_at "$file" "$SHA") || fail "cannot read $file at $SHA"
  source=$(answer _src_path "$answers")
  if [[ $source =~ $GITHUB_TEMPLATE ]]; then
    check_reference "$what" "${BASH_REMATCH[2]%.git}" "$(answer _commit "$answers")"
  else
    problem "$what: not a template on GitHub: $source"
  fi
}

# root_files: print the names of the files at the root of REPO at SHA, one per
# line.
root_files() {
  local listing
  listing=$(api_get "repos/$REPO/contents?ref=$SHA") || return 1
  jq -r '.[] | select(.type == "file") | .name' <<<"$listing"
}

check_templates() {
  local files file
  files=$(root_files) || fail "cannot list the files of $REPO at $SHA"
  while IFS= read -r file; do
    [[ ! $file =~ $ANSWERS_FILE ]] || check_template "$file"
  done <<<"$files"
}

if [[ $ENABLED != true ]]; then
  notice "the release tag check is off"
  exit 0
fi
check_allow_input
summary "| Reference | Immutable release |"
summary "| --- | --- |"
check_presets
check_templates
flush
! has_problems
