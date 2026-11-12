#!/usr/bin/env bash
# Emits a notice when the check of flake.lock does not run: when ENABLED=false
# switches it off, or when FLAKE is empty and there are no flake jobs; either
# way the check of the end of life of nixpkgs, a rule of it, does not run
# either. When the check runs, emits a notice when NIXPKGS_EOL=false switches
# off its check of the end of life. The check itself is a step of the flake
# jobs, which have no notice of their own.
set -euo pipefail
: "${SHELL_LIB:?}" "${ENABLED:?}" "${FLAKE?}" "${NIXPKGS_EOL:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "$SHELL_LIB/env.sh"
step_environment
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

if [[ $ENABLED != true ]]; then
  notice "the flake.lock check is off, and with it the end-of-life check of nixpkgs"
elif [[ -z $FLAKE ]]; then
  notice "no flake; no flake.lock to check"
else
  summary "flake.lock of $(code_span "$FLAKE"): checked in the flake jobs"
  [[ $NIXPKGS_EOL == true ]] || notice "the end-of-life check of nixpkgs is off"
fi
