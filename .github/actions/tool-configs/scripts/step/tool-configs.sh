#!/usr/bin/env bash
# Fails when, at commit SHA, an entry of any type exists at one of the
# standard root paths of the configuration files of atom tools, listed in
# paths.txt next to this script. The paths are found in listings of their
# directories, read through the contents API. ENABLED=false switches the check
# off.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}" "${REPO:?}" "${SHA:?}" "${ENABLED:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "$SHELL_LIB/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0004).
step_dir=${0%/*}
lib=$step_dir/../../../lib
# shellcheck source=../../../lib/github/directory.sh
source "$lib/github/directory.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

readonly PATHS=$step_dir/paths.txt
# A path below the root: names of letters, digits and ._- separated by "/";
# read_paths rules out the names "." and "..".
readonly PATH_FORM='^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$'

# The paths of paths.txt, and the entries of the listings of their
# directories.
paths=()
declare -A found=()

# read_paths: set paths to the lines of PATHS but comments and empty lines.
read_paths() {
  local line
  while IFS= read -r line; do
    [[ -n $line && $line != '#'* ]] || continue
    [[ $line =~ $PATH_FORM && /$line/ != */./* && /$line/ != */../* ]] \
      || fail "paths.txt: not a path below the root: $line"
    paths+=("$line")
  done <"$PATHS"
}

# dir_of PATH: print the directory of PATH, ROOT_DIR for the root.
dir_of() {
  local path=$1
  if [[ $path == */* ]]; then printf '%s\n' "${path%/*}"; else printf '%s\n' "$ROOT_DIR"; fi
}

# list_dir DIR: add the entries of the directory DIR, ROOT_DIR for the root,
# to found; a directory that does not exist has none.
list_dir() {
  local dir=$1 listing name status=0
  listing=$(directory_at "$dir" "$SHA") || status=$?
  ((status != NOT_FOUND)) || return 0
  ((status == 0)) || fail "cannot list ${dir:-the root} at $SHA"
  while IFS= read -r name; do
    found[${dir:+$dir/}$name]=1
  done < <(jq -r '.[].name' <<<"$listing")
}

# check_paths: list the directory of every path once, and report each path
# that exists.
check_paths() {
  local path dir
  declare -A listed=()
  for path in "${paths[@]}"; do
    dir=$(dir_of "$path")
    # Keyed by "/DIR": the root, "", is no key of an associative array.
    [[ -v listed["/$dir"] ]] && continue
    listed["/$dir"]=1
    list_dir "$dir"
  done
  for path in "${paths[@]}"; do
    [[ -v found[$path] ]] || continue
    problem "remove $path: the atom's default configuration of the tool applies; write each exception as an inline comment of the tool instead, such as # zizmor: ignore[<audit>]" "$path"
  done
}

if [[ $ENABLED != true ]]; then
  notice "the check of configuration files of atom tools is off"
  exit 0
fi
read_paths
check_paths
flush
! has_problems || exit 1
summary "no configuration files of atom tools"
