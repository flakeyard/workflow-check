#!/usr/bin/env bash
# Emits a notice when the check of flake.lock does not run: when ENABLED=false
# switches it off, or when FLAKE is empty and there are no flake jobs; either
# way the check of the end of life of nixpkgs, a rule of it, does not run
# either. When the check runs, emits a notice when NIXPKGS_EOL=false switches
# off its check of the end of life. The check itself is a step of the flake
# jobs, which have no notice of their own.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${ENABLED:?}" "${FLAKE?}" "${NIXPKGS_EOL:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/report.sh
source "$lib/report.sh"

if [[ $ENABLED != true ]]; then
  notice "the flake.lock check is off, and with it the end-of-life check of nixpkgs"
elif [[ -z $FLAKE ]]; then
  notice "no flake; no flake.lock to check"
else
  summary "flake.lock of $(code_span "$FLAKE"): checked in the flake jobs"
  [[ $NIXPKGS_EOL == true ]] || notice "the end-of-life check of nixpkgs is off"
fi
