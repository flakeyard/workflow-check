#!/usr/bin/env bash
# Fails unless OUTCOME, the outcome of a step, is EXPECTED: the jobs of the CI
# run the actions on fixtures that must fail and stay green when they do.
set -euo pipefail
: "${OUTCOME:?}" "${EXPECTED:?}"
if [[ $OUTCOME != "$EXPECTED" ]]; then
  echo "::error::the step's outcome is $OUTCOME, expected $EXPECTED"
  exit 1
fi
