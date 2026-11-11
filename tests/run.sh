#!/usr/bin/env bash
# Unit tests of the scripts in .github/actions, with the harness and the stubs
# of gh, date and sleep of internal/testing of the shell library and the stub
# of nix in tests/bin. The suites in tests/unit mirror the actions: one file
# per action, and one per helper under tests/unit/lib; tests/unit/workflows
# has one file per workflow and needs yq. The scripts and the harness come from SHELL_LIB,
# which must be action-shell-lib at the commit pinned in
# .github/workflows/check.yaml; checks.unit of the flake sets it.
# Usage: SHELL_LIB=DIR tests/run.sh
# shellcheck source-path=SCRIPTDIR
set -uo pipefail
shopt -s globstar

export SHELL_LIB=${SHELL_LIB:?the directory of action-shell-lib at the commit pinned in check.yaml}
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# The paths that run and run_lib take, and that yaml.sh reads.
# shellcheck disable=SC2034 # read by checks.sh and yaml.sh of the library
code_root=$root
# The stub of nix, on the PATH that the code under test gets.
PATH=$root/tests/bin:$PATH

testing=$SHELL_LIB/internal/testing
# shellcheck source=/dev/null
source "$testing/case.sh"
# shellcheck source=/dev/null
source "$testing/checks.sh"
# shellcheck source=/dev/null
source "$testing/fixtures.sh"
# shellcheck source=/dev/null
source "$testing/yaml.sh"
# shellcheck source=/dev/null
source "$testing/workflow.sh"
# shellcheck source=/dev/null
source "$testing/consumer/action.sh"
# shellcheck source=lib/action.sh
source "$root/tests/lib/action.sh"
# shellcheck source=lib/workflow.sh
source "$root/tests/lib/workflow.sh"

for suite in "$root"/tests/unit/**/*.sh; do
  # shellcheck source=/dev/null
  source "$suite"
done

conclude
