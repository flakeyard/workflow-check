#!/usr/bin/env bash
# Writes the inputs of action-flake-lock to GITHUB_OUTPUT: path, the lock file
# of the flake FLAKE relative to the workspace, and allow-duplicates, the
# sources of the JSON array ALLOW_DUPLICATES one per line. The action checks
# the form of every source; this script only keeps each source on its own line.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
# Ranges such as [a-z] match only ASCII, whatever the locale of the runner.
export LC_ALL=C.UTF-8
: "${FLAKE:?}" "${ALLOW_DUPLICATES?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/flake.sh
source "$lib/flake.sh"
# shellcheck source=../lib/report.sh
source "$lib/report.sh"

readonly LOCK_FILE=flake.lock
# A source is one word: a line break would split it in two lines of the list.
readonly SOURCE_FORM='\A[^[:space:]]+\z'
# Random, so that no source can end the multi-line output.
readonly UUID_FILE=/proc/sys/kernel/random/uuid

check_inputs() {
  [[ $FLAKE =~ $FLAKE_FORM ]] || fail "flake must be . or a path below it, not $FLAKE"
  jq -e --arg form "$SOURCE_FORM" 'type == "array" and all(.[]; type == "string" and test($form))' \
    <<<"$ALLOW_DUPLICATES" >/dev/null 2>&1 \
    || fail "allow-duplicates is not a JSON array of sources such as github.com/nixos/nixpkgs"
}

# lock_path: print the lock file of FLAKE, without a leading "./".
lock_path() {
  local dir=${FLAKE#.}
  dir=${dir#/}
  printf '%s\n' "${dir:+$dir/}$LOCK_FILE"
}

# write_lines NAME TEXT: write the output NAME of several lines.
write_lines() {
  local name=$1 text=$2 delimiter
  delimiter=EOF_$(<"$UUID_FILE")
  printf '%s<<%s\n%s\n%s\n' "$name" "$delimiter" "$text" "$delimiter" >>"$GITHUB_OUTPUT"
}

check_inputs
printf 'path=%s\n' "$(lock_path)" >>"$GITHUB_OUTPUT"
write_lines allow-duplicates "$(jq -r '.[]' <<<"$ALLOW_DUPLICATES")"
