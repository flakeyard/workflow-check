#!/usr/bin/env bash
# Unit tests of the scripts in .github/actions, with a stub of gh. The suites
# in tests/unit mirror the actions: one file per action, and one per helper
# under tests/unit/lib; tests/unit/scripts has one file per script of
# scripts/; tests/unit/workflows has one file per workflow and needs yq.
# The scripts source the shell library from SHELL_LIB, which must be
# action-shell-lib at the commit pinned in .github/workflows/check.yaml;
# checks.unit of the flake sets it.
# Usage: SHELL_LIB=DIR tests/run.sh
# shellcheck source-path=SCRIPTDIR
set -uo pipefail
shopt -s globstar

export SHELL_LIB=${SHELL_LIB:?the directory of action-shell-lib at the commit pinned in check.yaml}

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/case.sh
source "$root/tests/lib/case.sh"
# shellcheck source=lib/checks.sh
source "$root/tests/lib/checks.sh"
# shellcheck source=lib/fixtures/responses.sh
source "$root/tests/lib/fixtures/responses.sh"
# shellcheck source=lib/workflow.sh
source "$root/tests/lib/workflow.sh"

for suite in "$root"/tests/unit/**/*.sh; do
  # shellcheck source=/dev/null
  source "$suite"
done

echo "passed: $passed, failed: $failed"
((failed == 0))
