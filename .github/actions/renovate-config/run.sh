#!/usr/bin/env bash
# Fails unless, at commit SHA, renovate.json is the only Renovate
# configuration, is a JSON object and its extends lists a preset of a
# repository in PRESETS, or any preset when PRESETS is empty. Every file is
# read through the contents API. ENABLED=false switches the check off.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${REPO:?}" "${SHA:?}" "${ENABLED:?}" "${PRESETS?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/github/contents.sh
source "$lib/github/contents.sh"
# shellcheck source=../lib/github/repository.sh
source "$lib/github/repository.sh"
# shellcheck source=../lib/renovate.sh
source "$lib/renovate.sh"
# shellcheck source=../lib/report.sh
source "$lib/report.sh"

readonly CONFIG=renovate.json
# The other files that Renovate reads its configuration from.
readonly OTHER_CONFIGS=(
  renovate.json5 .renovaterc .renovaterc.json .renovaterc.json5
  .github/renovate.json .github/renovate.json5
  .gitlab/renovate.json .gitlab/renovate.json5
)
readonly PACKAGE_JSON=package.json
problems=0

# problem MESSAGE: report an error of the configuration and go on.
problem() {
  error "$*"
  problems=1
}

# exists PATH: PATH exists at SHA; exits on an error of the API.
exists() {
  local path=$1 status=0
  file_at "$path" "$SHA" >/dev/null 2>&1 || status=$?
  ((status != NOT_FOUND)) || return 1
  ((status == 0)) || fail "cannot read $path at $SHA"
}

check_presets_input() {
  jq -e --arg form "$REPOSITORY_FORM" \
    'type == "array" and all(.[]; type == "string" and test($form))' \
    <<<"$PRESETS" >/dev/null 2>&1 \
    || fail "renovate-presets is not a JSON array of owner/repo"
}

check_other_configs() {
  local path
  for path in "${OTHER_CONFIGS[@]}"; do
    if exists "$path"; then problem "remove $path: $CONFIG must be the only Renovate configuration"; fi
  done
  if exists "$PACKAGE_JSON" && file_at "$PACKAGE_JSON" "$SHA" \
    | jq -e 'type == "object" and has("renovate")' >/dev/null 2>&1; then
    problem "remove the key renovate of $PACKAGE_JSON: $CONFIG must be the only Renovate configuration"
  fi
}

# extends_listed_preset CONFIG: CONFIG extends a preset of a repository in
# PRESETS, compared without case as GitHub does.
extends_listed_preset() {
  local config=$1 preset repository
  [[ $(jq length <<<"$PRESETS") != 0 ]] || return 0
  while IFS= read -r preset; do
    repository=$(preset_repository "$preset") || continue
    jq -e --arg repository "$repository" \
      'any(.[]; ascii_downcase == ($repository | ascii_downcase))' <<<"$PRESETS" >/dev/null \
      && return 0
  done < <(jq -r '.extends[]' <<<"$config")
  return 1
}

# check_config CONFIG: the content of renovate.json has the expected form.
check_config() {
  local config=$1
  jq -e 'type == "object"' <<<"$config" >/dev/null 2>&1 \
    || {
      problem "$CONFIG is not a JSON object"
      return
    }
  jq -e '.extends | type == "array" and length > 0
    and all(.[]; type == "string" and (test("[\\n\\r]") | not))' <<<"$config" >/dev/null \
    || {
      problem "$CONFIG must extend presets: extends must be a non-empty array of one-line strings"
      return
    }
  extends_listed_preset "$config" \
    || problem "$CONFIG must extend a preset of one of: $(jq -r 'join(", ")' <<<"$PRESETS")"
}

check_renovate_json() {
  local config status=0
  config=$(file_at "$CONFIG" "$SHA" 2>/dev/null) || status=$?
  if ((status == NOT_FOUND)); then
    problem "$CONFIG is missing: the repository needs its own Renovate configuration"
    return
  fi
  ((status == 0)) || fail "cannot read $CONFIG at $SHA"
  check_config "$config"
}

if [[ $ENABLED != true ]]; then
  notice "the renovate.json check is off"
  exit 0
fi
check_presets_input
check_other_configs
check_renovate_json
((problems == 0)) || exit 1
summary "$(code_span "$CONFIG") is the only Renovate configuration and extends a listed preset"
