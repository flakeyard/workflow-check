# shellcheck shell=bash
# The form of the input flake, as the actions read it. Source this file after
# report.sh.

# The flake is in the checked-out repository: "." or a path below it.
readonly FLAKE_FORM='^\.(/[A-Za-z0-9_][A-Za-z0-9._-]*)*$'

# check_flake FLAKE: fails unless FLAKE has the form of FLAKE_FORM.
check_flake() {
  local flake=$1
  [[ $flake =~ $FLAKE_FORM ]] || fail "flake must be . or a path below it, not $flake"
}
