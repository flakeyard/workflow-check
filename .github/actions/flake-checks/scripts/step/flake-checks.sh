#!/usr/bin/env bash
# Checks the flake FLAKE natively on SYSTEM: fails when Nix runs for another
# system, when the systems the flake declares differ from those of SYSTEMS,
# when the flake does not evaluate, when a check of EXPECT_CHECKS is missing
# or when a check fails to build. Every command that reads the flake overrides
# the inputs of OVERRIDE_INPUTS, a JSON object of input names and flake
# references, and reports them. Writes a table of the checks to the job
# summary.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}" "${FLAKE:?}" "${SYSTEM:?}" "${SYSTEMS:?}" "${EXPECT_CHECKS:?}" "${OVERRIDE_INPUTS:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "$SHELL_LIB/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0004).
lib=${0%/*}/../../../lib
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"
# shellcheck source=../../../lib/flake.sh
source "$lib/flake.sh"

readonly SYSTEM_FORM='^[a-z0-9_]+-[a-z0-9_]+$'
readonly CHECK_NAME_FORM='^[A-Za-z0-9_][A-Za-z0-9_.+-]*$'
# The names of the inputs of the root, which override-inputs may override,
# and the schemes of the references it may override them with (ADR-0005). jq,
# whose $ also matches before a final newline, so \A and \z.
readonly INPUT_NAME_FORM='\A[A-Za-z_][A-Za-z0-9_-]*\z'
readonly REFERENCE_SCHEMES='["git+https://", "github:"]'
# Whitespace and control characters, which no reference may contain.
readonly REFERENCE_SPACE='[\s\p{Cc}]'
# Every command that reads the flake uses flake.lock as committed, with the
# inputs of OVERRIDE_INPUTS overridden; check_overrides adds them.
flake_options=(--no-update-lock-file)
# The overridden inputs, each name followed by its reference.
overridden=()
# The systems of every per-system output, applied to the outputs of the flake.
# shellcheck disable=SC2016 # Nix, not shell.
readonly DECLARED_SYSTEMS='outputs: builtins.concatMap
  (name: builtins.attrNames (outputs.${name} or { }))
  [ "checks" "packages" "apps" "devShells" "formatter" ]'

check_inputs() {
  check_flake "$FLAKE"
  [[ $SYSTEM =~ $SYSTEM_FORM ]] || fail "not a system: $SYSTEM"
  jq -e 'type == "array" and length > 0
    and all(.[]; (.system | type) == "string" and (.runner | type) == "string")' \
    <<<"$SYSTEMS" >/dev/null 2>&1 || fail "systems is not a JSON array of {system, runner}"
  jq -e --arg form "$CHECK_NAME_FORM" 'type == "array" and all(.[]; type == "string" and test($form))' \
    <<<"$EXPECT_CHECKS" >/dev/null 2>&1 || fail "expect-checks is not a JSON array of check names"
  check_overrides
}

# check_overrides: OVERRIDE_INPUTS has the form of ADR-0005; add an
# --override-input for each of its inputs to flake_options, and the inputs to
# overridden.
check_overrides() {
  local problems line name reference
  jq -e 'type == "object"' <<<"$OVERRIDE_INPUTS" >/dev/null 2>&1 \
    || fail "override-inputs is not a JSON object"
  problems=$(jq -r --arg form "$INPUT_NAME_FORM" --argjson schemes "$REFERENCE_SCHEMES" \
    --arg space "$REFERENCE_SPACE" '
    to_entries[]
    | if (.key | test($form) | not) then "not the name of an input: \(.key | tojson)"
      elif (.value | type == "string" and any($schemes[] as $scheme | startswith($scheme); .)
        and (test($space) | not)) | not then
        "the reference of \(.key) must start with \($schemes | join(" or ")) and have no whitespace or control characters"
      else empty end' <<<"$OVERRIDE_INPUTS")
  while IFS= read -r line; do
    [[ -z $line ]] || problem "override-inputs: $line"
  done <<<"$problems"
  flush
  ! has_problems || exit 1
  # Names and references hold no NUL, which separates them.
  while IFS= read -r -d '' name && IFS= read -r -d '' reference; do
    flake_options+=(--override-input "$name" "$reference")
    overridden+=("$name" "$reference")
  done < <(jq -j 'to_entries[] | .key, "\u0000", .value, "\u0000"' <<<"$OVERRIDE_INPUTS")
}

# report_overrides: list the overridden inputs with their references in a
# notice and in the job summary, above the table of the checks.
report_overrides() {
  local i list=""
  ((${#overridden[@]} > 0)) || return 0
  summary "Inputs overridden on $SYSTEM:"
  summary ""
  for ((i = 0; i < ${#overridden[@]}; i += 2)); do
    list+="${list:+, }${overridden[i]} = ${overridden[i + 1]}"
    summary "- $(code_span "${overridden[i]}"): $(code_span "${overridden[i + 1]}")"
  done
  summary ""
  notice "inputs overridden on $SYSTEM: $list"
}

check_native() {
  local nix_system
  nix_system=$("$nix" config show system) || fail "cannot read the system of Nix"
  [[ $nix_system == "$SYSTEM" ]] || fail "Nix builds for $nix_system on the runner of $SYSTEM; CI does not emulate other systems"
}

# check_systems: the flake declares exactly the systems of SYSTEMS.
check_systems() {
  local declared given
  declared=$("$nix" eval "${flake_options[@]}" --json "$FLAKE#." --apply "$DECLARED_SYSTEMS" | jq -c 'unique') \
    || fail "cannot evaluate the systems of the flake $FLAKE"
  given=$(jq -c '[.[].system] | unique' <<<"$SYSTEMS")
  [[ $declared == "$given" ]] && return 0
  fail "$(jq -rn --argjson declared "$declared" --argjson given "$given" '
    "the flake declares the systems \($declared | join(", ")) but has runners for \($given | join(", "))"')"
}

check_evaluation() {
  "$nix" flake check "${flake_options[@]}" --no-build --option accept-flake-config false "$FLAKE" \
    || fail "the flake $FLAKE does not evaluate on $SYSTEM"
}

# check_names: set names to the names of the checks for SYSTEM; fails when an
# expected one is missing.
check_names() {
  local found missing
  found=$("$nix" eval "${flake_options[@]}" --json "$FLAKE#." \
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
  "$nix" build "${flake_options[@]}" --no-link --print-build-logs --keep-going "${installables[@]}" || true
  summary "| Check on $SYSTEM | Result |"
  summary "| --- | --- |"
  for name; do
    if "$nix" path-info "${flake_options[@]}" "$(installable "$name")" >/dev/null 2>&1; then
      summary "| $(code_span "$name") | built |"
    else
      summary "| $(code_span "$name") | failed |"
      failed+=("$name")
    fi
  done
  ((${#failed[@]} == 0)) || fail "checks that failed on $SYSTEM: ${failed[*]}"
}

check_inputs
report_overrides
# action-setup-nix puts nix on the PATH of the job; every other tool comes
# from SYSTEM_PATH.
nix=$(job_tool nix) \
  || fail "no nix on the PATH of the job: install Nix before this step, such as with flakeyard/action-setup-nix"
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
