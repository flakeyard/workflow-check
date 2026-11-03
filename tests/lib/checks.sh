# shellcheck shell=bash
# Runs of an action script or a helper, and checks of what it did. Source this
# file after case.sh; it expects root, the repository's directory.
# shellcheck disable=SC2154 # work is the directory of the test, from setup.

: "${root:?}"
actions=$root/.github/actions

# outcome NAME EXPECTED STATUS: start test NAME, which exited with STATUS;
# EXPECTED is ok or fail.
outcome() {
  local name=$1 expected=$2 status=$3
  current=$name
  if [[ $expected == fail && $status -eq 0 ]] || [[ $expected == ok && $status -ne 0 ]]; then
    report "expected $expected, exit status $status: $(cat "$work/stdout" "$work/stderr")"
  fi
}

# run NAME EXPECTED SCRIPT: run an action script; EXPECTED is ok or fail.
run() {
  local name=$1 expected=$2 script=$3 status=0
  "$actions/$script" >"$work/stdout" 2>"$work/stderr" || status=$?
  outcome "$name" "$expected" "$status"
}

# run_lib NAME EXPECTED LIB FUNCTION [ARG...]: run a function of the helper
# lib/LIB in a subshell; EXPECTED is ok or fail.
run_lib() {
  local name=$1 expected=$2 lib=$3 status=0
  shift 3
  (
    # shellcheck source=/dev/null
    source "$actions/lib/$lib"
    "$@"
  ) >"$work/stdout" 2>"$work/stderr" || status=$?
  outcome "$name" "$expected" "$status"
}

# expect KIND [VALUE...]: check outputs, calls, messages or the summary of the
# last run.
expect() {
  [[ -n $current ]] || return 0
  case $1 in
    output)
      local value
      value=$(sed -n "s/^$2=//p" "$GITHUB_OUTPUT")
      [[ $value == "$3" ]] || report "output $2 is '$value', expected '$3'"
      ;;
    stdout)
      [[ $(cat "$work/stdout") == "$2" ]] || report "stdout is '$(cat "$work/stdout")', expected '$2'"
      ;;
    call) grep -qF -- "$2" "$CALLS" || report "no call '$2' in: $(paste -sd';' "$CALLS")" ;;
    no-calls) [[ ! -s $CALLS ]] || report "unexpected calls: $(paste -sd';' "$CALLS")" ;;
    message) grep -qF -- "$2" "$work/stdout" "$work/stderr" || report "no message '$2' in: $(cat "$work/stdout" "$work/stderr")" ;;
    no-message) ! grep -qF -- "$2" "$work/stdout" "$work/stderr" || report "unexpected message '$2'" ;;
    no-command) ! grep -q -- "^::$2::" "$work/stdout" || report "unexpected command ::$2::" ;;
    summary) grep -qF -- "$2" "$GITHUB_STEP_SUMMARY" || report "no '$2' in the summary: $(cat "$GITHUB_STEP_SUMMARY")" ;;
  esac
}
