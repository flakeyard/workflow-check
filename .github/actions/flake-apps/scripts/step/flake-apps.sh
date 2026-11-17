#!/usr/bin/env bash
# Runs the apps of APPS, a JSON array of app names, of the flake FLAKE on
# SYSTEM, each with nix run from the root of the checkout in
# GITHUB_WORKSPACE, in the order given and also after one failed (ADR-0006).
# Fails when an app is missing, before any app runs, and when an app fails.
# An empty APPS runs none and succeeds with a notice. The apps get GH_TOKEN
# and GITHUB_TOKEN. Writes a table of the apps to the job summary.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}" "${FLAKE:?}" "${SYSTEM:?}" "${APPS?}" "${GITHUB_WORKSPACE:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0004).
lib=${0%/*}/../../../lib
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"
# shellcheck source=../../../lib/flake.sh
source "${lib}/flake.sh"
# shellcheck source=../../../lib/outputs.sh
source "${lib}/outputs.sh"
# shellcheck source=../../../lib/apps.sh
source "${lib}/apps.sh"

# Every command that reads the flake uses flake.lock as committed.
readonly FLAKE_OPTIONS=(--no-update-lock-file --option accept-flake-config false)
# The apps of APPS, which read_names sets.
apps=()

check_inputs() {
  check_flake "${FLAKE}"
  check_system "${SYSTEM}"
  check_apps "${APPS}"
}

# run_apps NAME...: run every app, then report which succeeded.
run_apps() {
  local name failed=() span
  summary "| App on ${SYSTEM} | Result |"
  summary "| --- | --- |"
  for name; do
    span=$(code_span "${name}")
    if "${nix}" run "${FLAKE_OPTIONS[@]}" "${FLAKE}#.apps.${SYSTEM}.\"${name}\""; then
      summary "| ${span} | succeeded |"
    else
      summary "| ${span} | failed |"
      failed+=("${name}")
    fi
  done
  ((${#failed[@]} == 0)) || fail "apps that failed on ${SYSTEM}: ${failed[*]}"
}

check_inputs
read_names apps "${APPS}"
if ((${#apps[@]} == 0)); then
  notice "no apps of the flake to run on ${SYSTEM}"
  exit 0
fi
find_nix
# The flake is a path below the root of the checkout, and the apps check the
# files of the project there, such as an app of ./dev that checks the links of
# the whole repository.
cd -- "${GITHUB_WORKSPACE}" || fail "cannot enter the checkout ${GITHUB_WORKSPACE}"
# Fails on a missing app before any app runs.
output_names "${FLAKE}" "${SYSTEM}" apps "${APPS}" "${FLAKE_OPTIONS[@]}"
run_apps "${apps[@]}"
