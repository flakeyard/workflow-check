#!/usr/bin/env bash
# Writes context=<caller prefix>required to GITHUB_OUTPUT, from the name of
# the job with the check run CHECK_RUN_ID. The caller chooses the prefix
# through the id of its job; a ruleset that requires "check / required" is
# satisfied only by the caller job "check".
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
# Ranges such as [a-z] match only ASCII, whatever the locale of the runner.
export LC_ALL=C.UTF-8
: "${REPO:?}" "${CHECK_RUN_ID?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/github/jobs.sh
source "$lib/github/jobs.sh"
# shellcheck source=../lib/report.sh
source "$lib/report.sh"

readonly REQUIRED_JOB=required

name=$(job_name "$CHECK_RUN_ID") || fail "cannot read the name of job $CHECK_RUN_ID"
context=$(caller_prefix "$name")$REQUIRED_JOB
printf 'context=%s\n' "$context" >>"$GITHUB_OUTPUT"
summary "status context: $(code_span "$context")"
