# shellcheck shell=bash
# The tests of the action scripts on top of internal/testing of the shell
# library: the copy of the library that the steps run, the variables that every
# script reads, the locale of the runner and outputs of several lines. Source
# this file after case.sh, checks.sh, yaml.sh, consumer/library.sh,
# consumer/action.sh and consumer/step.sh; it expects root, the repository's
# directory.
# shellcheck disable=SC2154 # work and current come from case.sh.
# shellcheck disable=SC2034 # ACTIONS is read by the suites.

: "${SHELL_LIB:?}" "${root:?}"

# The repository and the commit that the scripts check.
readonly REPO=o/r SHA=aaa
# A locale in which ranges such as [a-z] match letters beyond ASCII, such as
# é: the action scripts must not depend on the locale of the runner.
readonly WIDE_LOCALE=en_US.UTF-8
# The tools of the runner that the scripts run from SYSTEM_PATH.
readonly RUNNER_TOOLS=(base64 bash cat env grep jq mktemp rm sed)
# The directory of the internal actions, ACTIONS/<name>/action.yml.
readonly ACTIONS=$root/.github/actions

# Files shared by all tests, removed at the end.
shared=$(mktemp -d)
trap 'rm -rf -- "$shared"' EXIT
sysbin=$shared/bin
mkdir "$sysbin"
for tool in "${RUNNER_TOOLS[@]}"; do
  ln -s "$(command -v "$tool")" "$sysbin/$tool"
done

# The copy of the library that the steps run, whose SYSTEM_PATH is the stubs
# of the library and the tools of the runner.
shell_lib=$shared/shell-lib
copy_library "$shell_lib" "$TESTING_BIN:$sysbin"
readonly shell_lib

# action_setup: setup for a run of an action script, which reads the library,
# the repository and the commit.
action_setup() {
  setup
  apply SHELL_LIB="$shell_lib" REPO="$REPO" SHA="$SHA"
}

# has_wide_ranges: the system has WIDE_LOCALE, and [a-z] matches é in it.
has_wide_ranges() {
  LC_ALL=$WIDE_LOCALE bash -c '[[ é =~ ^[a-z]$ ]]' 2>/dev/null
}

# apply_wide_locale: run the script under test in WIDE_LOCALE, with the
# locales of the tests when they come from LOCALE_ARCHIVE.
apply_wide_locale() {
  apply LC_ALL="$WIDE_LOCALE"
  [[ -z ${LOCALE_ARCHIVE-} ]] || apply LOCALE_ARCHIVE="$LOCALE_ARCHIVE"
}

# multiline_output NAME: print the lines of the output NAME, written as
# NAME<<DELIMITER, the lines and DELIMITER.
multiline_output() {
  local name=$1
  awk -v start="$name<<" '
    delimiter != "" && $0 == delimiter { delimiter = ""; next }
    delimiter != "" { print }
    index($0, start) == 1 { delimiter = substr($0, length(start) + 1) }
  ' "$work/output"
}

# expect_lines NAME VALUE: the output NAME of several lines of the last run is
# VALUE.
expect_lines() {
  local name=$1 expected=$2 lines
  [[ -n $current ]] || return 0
  lines=$(multiline_output "$name")
  [[ $lines == "$expected" ]] || report "output $name is '$lines', expected '$expected'"
}

# listing_fixture DIR ENTRY...: answer the listing of the directory DIR of
# REPO at SHA, "" for the root, with ENTRY..., each a file, or a directory
# when it ends with "/".
listing_fixture() {
  local dir=$1
  shift
  fixture "repos/$REPO/contents${dir:+/$dir}?ref=$SHA" "$(jq -nc '$ARGS.positional
    | map(if endswith("/") then {name: rtrimstr("/"), type: "dir"} else {name: ., type: "file"} end)' \
    --args -- "$@")"
}

# expect_calls COUNT: the last run made COUNT requests of the gh stub; GETs
# count only when LOG_GETS is applied.
expect_calls() {
  local expected=$1 count
  [[ -n $current ]] || return 0
  count=$(wc -l <"$work/calls")
  [[ $count == "$expected" ]] || report "$count calls, expected $expected: $(paste -sd';' "$work/calls")"
}
