#!/usr/bin/env bash
# Fails unless, at commit SHA, renovate.json is the only Renovate
# configuration, is a JSON object and its extends lists a preset of a
# repository in PRESETS, or any preset when PRESETS is empty. Every file is
# read through the contents API, and the other configurations are found in
# listings of their directories. ENABLED=false switches the check off.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}" "${REPO:?}" "${SHA:?}" "${ENABLED:?}" "${PRESETS?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0004).
lib=${0%/*}/../../../lib
# shellcheck source=/dev/null
source "${SHELL_LIB}/github/contents.sh"
# shellcheck source=/dev/null
source "${SHELL_LIB}/github/forms.sh"
# shellcheck source=../../../lib/github/directory.sh
source "${lib}/github/directory.sh"
# shellcheck source=../../../lib/renovate.sh
source "${lib}/renovate.sh"
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"

readonly CONFIG=renovate.json
# The other files that Renovate reads its configuration from.
readonly OTHER_CONFIGS=(
  renovate.json5 .renovaterc .renovaterc.json .renovaterc.json5
  .github/renovate.json .github/renovate.json5
  .gitlab/renovate.json .gitlab/renovate.json5
)
readonly PACKAGE_JSON=package.json
# The directories below the root that hold other configurations.
readonly CONFIG_DIRS=(.github .gitlab)
# The jq filter that prints the paths of the entries of a listing of the
# directory $dir, ROOT_DIR for the root, with their types, one per line.
# shellcheck disable=SC2016 # jq, not shell.
readonly ENTRY_PATHS='.[] | "\(.type) \(if $dir == "" then "" else "\($dir)/" end)\(.name)"'

# The type of every path that a listing found, by path.
declare -A types=()

# list_dir DIR: add the entries of the directory DIR, ROOT_DIR for the root,
# to types; exits on an error of the API.
list_dir() {
  local dir=$1 listing entries type path
  # shellcheck disable=SC2310 # directory_at returns its failure itself.
  listing=$(directory_at "${dir}" "${SHA}") || fail "cannot list ${dir:-the root} at ${SHA}"
  entries=$(jq -r --arg dir "${dir}" "${ENTRY_PATHS}" <<<"${listing}")
  while read -r type path; do
    [[ -n ${path} ]] || continue
    types[${path}]=${type}
  done <<<"${entries}"
}

# list_config_dirs: add the entries of the root, and of each directory of
# CONFIG_DIRS that it has, to types.
list_config_dirs() {
  local dir
  list_dir "${ROOT_DIR}"
  for dir in "${CONFIG_DIRS[@]}"; do
    if [[ ${types[${dir}]-} == dir ]]; then list_dir "${dir}"; fi
  done
}

check_presets_input() {
  is_repository_list "${PRESETS}" || fail "renovate-presets is not a JSON array of owner/repo"
}

check_other_configs() {
  local path package
  list_config_dirs
  for path in "${OTHER_CONFIGS[@]}"; do
    if [[ -v types[${path}] ]]; then problem "remove ${path}: ${CONFIG} must be the only Renovate configuration"; fi
  done
  [[ -v types[${PACKAGE_JSON}] ]] || return 0
  package=$(file_at "${PACKAGE_JSON}" "${SHA}") || fail "cannot read ${PACKAGE_JSON} at ${SHA}"
  if jq -e 'type == "object" and has("renovate")' <<<"${package}" >/dev/null 2>&1; then
    problem "remove the key renovate of ${PACKAGE_JSON}: ${CONFIG} must be the only Renovate configuration"
  fi
}

# check_listed_preset CONFIG: a problem unless CONFIG extends a preset of a
# repository in PRESETS, compared without case as GitHub does.
check_listed_preset() {
  local config=$1 count presets preset repository listed
  count=$(jq length <<<"${PRESETS}")
  [[ ${count} != 0 ]] || return 0
  presets=$(jq -r '.extends[]' <<<"${config}")
  while IFS= read -r preset; do
    # shellcheck disable=SC2310 # preset_repository only tests the text of the preset.
    repository=$(preset_repository "${preset}") || continue
    lists_repository "${PRESETS}" "${repository}" && return 0
  done <<<"${presets}"
  listed=$(jq -r 'join(", ")' <<<"${PRESETS}")
  problem "${CONFIG} must extend a preset of one of: ${listed}"
}

# check_config CONFIG: the content of renovate.json has the expected form.
check_config() {
  local config=$1
  jq -e 'type == "object"' <<<"${config}" >/dev/null 2>&1 \
    || {
      problem "${CONFIG} is not a JSON object"
      return
    }
  jq -e "${PRESET_LIST_DEF}"' .extends | preset_list and length > 0' <<<"${config}" >/dev/null \
    || {
      problem "${CONFIG} must extend presets: extends must be a non-empty array of one-line strings"
      return
    }
  check_listed_preset "${config}"
}

check_renovate_json() {
  local config status=0
  config=$(file_at "${CONFIG}" "${SHA}" 2>/dev/null) || status=$?
  if ((status == NOT_FOUND)); then
    problem "${CONFIG} is missing: the repository needs its own Renovate configuration"
    return
  fi
  ((status == 0)) || fail "cannot read ${CONFIG} at ${SHA}"
  check_config "${config}"
}

if [[ ${ENABLED} != true ]]; then
  notice "the renovate.json check is off"
  exit 0
fi
check_presets_input
check_other_configs
check_renovate_json
flush
! has_problems || exit 1
config_span=$(code_span "${CONFIG}")
summary "${config_span} is the only Renovate configuration and extends a listed preset"
