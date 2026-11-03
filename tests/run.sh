#!/usr/bin/env bash
# Unit tests of the scripts in .github/actions, with a stub of gh. The suites
# in tests/unit mirror the actions: one file per action, and one per helper
# under tests/unit/lib; tests/unit/workflows has one file per workflow and
# needs yq.
# Usage: tests/run.sh
# shellcheck source-path=SCRIPTDIR
set -uo pipefail
shopt -s globstar

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
