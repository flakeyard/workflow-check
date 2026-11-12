#!/usr/bin/env bash
# Writes context=<caller prefix>required to GITHUB_OUTPUT, from the name of
# the job with the check run CHECK_RUN_ID. The caller chooses the prefix
# through the id of its job; a ruleset that requires "check / required" is
# satisfied only by the caller job "check".
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}" "${REPO:?}" "${CHECK_RUN_ID?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "$SHELL_LIB/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0004).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/github/jobs.sh
source "$lib/github/jobs.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

readonly REQUIRED_JOB=required

name=$(job_name "$CHECK_RUN_ID") || fail "cannot read the name of job $CHECK_RUN_ID"
context=$(caller_prefix "$name")$REQUIRED_JOB
printf 'context=%s\n' "$context" >>"$GITHUB_OUTPUT"
summary "status context: $(code_span "$context")"
