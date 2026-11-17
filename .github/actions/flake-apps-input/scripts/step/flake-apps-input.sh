#!/usr/bin/env bash
# Fails when APPS is not a JSON array of app names, and when it names apps but
# FLAKE is empty: there are no flake jobs then, and the apps would not run
# without a word (ADR-0006). The apps themselves run in the flake jobs.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}" "${FLAKE?}" "${APPS?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0004).
lib=${0%/*}/../../../lib
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"
# shellcheck source=../../../lib/outputs.sh
source "${lib}/outputs.sh"
# shellcheck source=../../../lib/apps.sh
source "${lib}/apps.sh"

check_apps "${APPS}"
if [[ -z ${FLAKE} ]] && jq -e 'length > 0' <<<"${APPS}" >/dev/null; then
  fail "apps names apps of the flake, but flake is empty, so no flake job runs them; set flake or pass apps: []"
fi
