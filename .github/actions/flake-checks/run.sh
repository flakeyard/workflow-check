#!/usr/bin/env bash
# Checks the flake FLAKE natively on SYSTEM: fails when Nix runs for another
# system, when the systems the flake declares differ from those of SYSTEMS,
# when the flake does not evaluate, when a check of EXPECT_CHECKS is missing
# or when a check fails to build. Writes a table of the checks to the job
# summary.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${FLAKE:?}" "${SYSTEM:?}" "${SYSTEMS:?}" "${EXPECT_CHECKS:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/report.sh
source "$lib/report.sh"

# The flake is in the checked-out repository: "." or a path below it.
readonly FLAKE_FORM='^\.(/[A-Za-z0-9_][A-Za-z0-9._-]*)*$'
readonly SYSTEM_FORM='^[a-z0-9_]+-[a-z0-9_]+$'
readonly CHECK_NAME_FORM='^[A-Za-z0-9_][A-Za-z0-9_.+-]*$'
# Every command that reads the flake uses flake.lock as committed.
readonly LOCKED=(--no-update-lock-file)
# The systems of every per-system output, applied to the outputs of the flake.
# shellcheck disable=SC2016 # Nix, not shell.
readonly DECLARED_SYSTEMS='outputs: builtins.concatMap
  (name: builtins.attrNames (outputs.${name} or { }))
  [ "checks" "packages" "apps" "devShells" "formatter" ]'

check_inputs() {
  [[ $FLAKE =~ $FLAKE_FORM ]] || fail "flake must be . or a path below it, not $FLAKE"
  [[ $SYSTEM =~ $SYSTEM_FORM ]] || fail "not a system: $SYSTEM"
  jq -e 'type == "array" and length > 0
    and all(.[]; (.system | type) == "string" and (.runner | type) == "string")' \
    <<<"$SYSTEMS" >/dev/null 2>&1 || fail "systems is not a JSON array of {system, runner}"
  jq -e --arg form "$CHECK_NAME_FORM" 'type == "array" and all(.[]; type == "string" and test($form))' \
    <<<"$EXPECT_CHECKS" >/dev/null 2>&1 || fail "expect-checks is not a JSON array of check names"
}

check_native() {
  local nix_system
  nix_system=$(nix config show system) || fail "cannot read the system of Nix"
  [[ $nix_system == "$SYSTEM" ]] || fail "Nix builds for $nix_system on the runner of $SYSTEM; CI does not emulate other systems"
}

# check_systems: the flake declares exactly the systems of SYSTEMS.
check_systems() {
  local declared given
  declared=$(nix eval "${LOCKED[@]}" --json "$FLAKE#." --apply "$DECLARED_SYSTEMS" | jq -c 'unique') \
    || fail "cannot evaluate the systems of the flake $FLAKE"
  given=$(jq -c '[.[].system] | unique' <<<"$SYSTEMS")
  [[ $declared == "$given" ]] && return 0
  fail "$(jq -rn --argjson declared "$declared" --argjson given "$given" '
    "the flake declares the systems \($declared | join(", ")) but has runners for \($given | join(", "))"')"
}

check_evaluation() {
  nix flake check "${LOCKED[@]}" --no-build --option accept-flake-config false "$FLAKE" \
    || fail "the flake $FLAKE does not evaluate on $SYSTEM"
}

# check_names: set names to the names of the checks for SYSTEM; fails when an
# expected one is missing.
check_names() {
  local found missing
  found=$(nix eval "${LOCKED[@]}" --json "$FLAKE#." \
    --apply "outputs: builtins.attrNames ((outputs.checks or { }).\"$SYSTEM\" or { })") \
    || fail "cannot evaluate the checks of the flake $FLAKE"
  missing=$(jq -r --argjson found "$found" '. - $found | join(", ")' <<<"$EXPECT_CHECKS")
  [[ -z $missing ]] || fail "the flake $FLAKE has no checks.$SYSTEM of: $missing"
  jq -e --arg form "$CHECK_NAME_FORM" 'all(.[]; test($form))' <<<"$found" >/dev/null \
    || fail "check names must match $CHECK_NAME_FORM"
  mapfile -t names < <(jq -r '.[]' <<<"$found")
}

# installable NAME: the installable of the check NAME for SYSTEM.
installable() {
  printf '%s#.checks.%s."%s"\n' "$FLAKE" "$SYSTEM" "$1"
}

# build_checks NAME...: build every check, then report which were built.
build_checks() {
  local name installables=() failed=()
  for name; do installables+=("$(installable "$name")"); done
  nix build "${LOCKED[@]}" --no-link --print-build-logs --keep-going "${installables[@]}" || true
  summary "| Check on $SYSTEM | Result |"
  summary "| --- | --- |"
  for name; do
    if nix path-info "${LOCKED[@]}" "$(installable "$name")" >/dev/null 2>&1; then
      summary "| $(code_span "$name") | built |"
    else
      summary "| $(code_span "$name") | failed |"
      failed+=("$name")
    fi
  done
  ((${#failed[@]} == 0)) || fail "checks that failed on $SYSTEM: ${failed[*]}"
}

check_inputs
check_native
# The flake check runs first: it reports a lock file that does not match.
check_evaluation
check_systems
check_names
if ((${#names[@]} == 0)); then
  notice "the flake $FLAKE has no checks for $SYSTEM"
  exit 0
fi
build_checks "${names[@]}"
