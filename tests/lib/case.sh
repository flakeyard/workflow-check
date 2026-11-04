# shellcheck shell=bash
# The life of one test: its fixtures directory, environment and count. Source
# this file; it expects root, the repository's directory.

: "${root:?}"
failed=0 passed=0 current=""

# The variables that action scripts read, unset before every test.
readonly SCRIPT_VARIABLES=(
  EVENT FAIL_ON CHECK_RUN_ID STATE CONTEXT RUN_URL
  RUN_ID RUN_ATTEMPT CALLER CHECK CALLER_MAY_SKIP CHECK_MAY_SKIP
  NUMBER OWNER BRANCH ENABLED TYPES PRESETS ALLOW_UNPINNED
  FLAKE SYSTEM SYSTEMS EXPECT_CHECKS
  NIX_SYSTEM NIX_DECLARED NIX_CHECKS NIX_EVAL_ERROR NIX_FAILED NIX_STALE_LOCK
)

# setup: fresh fixtures, calls, outputs and environment for one test.
setup() {
  work=$(mktemp -d)
  export FIXTURES=$work/fixtures CALLS=$work/calls GITHUB_OUTPUT=$work/output
  export GITHUB_STEP_SUMMARY=$work/summary PATH=$root/tests/bin:$PATH
  mkdir -p "$FIXTURES"
  : >"$CALLS"
  : >"$GITHUB_OUTPUT"
  : >"$GITHUB_STEP_SUMMARY"
  unset "${SCRIPT_VARIABLES[@]}"
  export REPO=o/r SHA=aaa
}

# apply NAME=VALUE...: export variables to the script under test.
apply() {
  local pair
  for pair; do
    if [[ ! $pair =~ ^[A-Z][A-Z0-9_]*= ]]; then
      echo "apply: not NAME=VALUE: $pair" >&2
      exit 2
    fi
    declare -gx -- "$pair"
  done
}

# report MESSAGE: fail the current test.
report() {
  [[ -n $current ]] || return 0
  echo "FAIL $current: $1"
  failed=$((failed + 1))
  current=""
}

# finish: count the current test and remove its files.
finish() {
  if [[ -n $current ]]; then passed=$((passed + 1)); fi
  current=""
  rm -rf "$work"
}
