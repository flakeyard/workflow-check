#!/usr/bin/env bash
# Fails unless EVENT, the event of the caller, is one that the check workflow
# supports. Events that run code or tokens of another context, such as
# pull_request_target and workflow_run, are rejected with every other one.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${EVENT?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/report.sh
source "$lib/report.sh"

readonly SUPPORTED_EVENTS='^(pull_request|push|schedule|workflow_dispatch)$'

[[ $EVENT =~ $SUPPORTED_EVENTS ]] \
  || fail "the check workflow runs on pull_request, push, schedule and workflow_dispatch, not $EVENT"
summary "event: $(code_span "$EVENT")"
