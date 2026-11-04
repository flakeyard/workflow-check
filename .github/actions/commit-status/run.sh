#!/usr/bin/env bash
# Posts the commit status STATE with CONTEXT on SHA, linked to RUN_URL.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
# Ranges such as [a-z] match only ASCII, whatever the locale of the runner.
export LC_ALL=C.UTF-8
: "${REPO:?}" "${SHA:?}" "${STATE?}" "${CONTEXT?}" "${RUN_URL:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/report.sh
source "$lib/report.sh"

readonly STATES='^(pending|success|failure)$'
readonly DESCRIPTION='GitHub Actions run'

[[ $STATE =~ $STATES ]] || fail "not a commit status state: $STATE"
[[ -n $CONTEXT ]] || fail "the status context is empty"
gh api --silent -X POST "repos/$REPO/statuses/$SHA" \
  -f state="$STATE" -f context="$CONTEXT" -f target_url="$RUN_URL" \
  -f description="$DESCRIPTION"
summary "posted $STATE as $(code_span "$CONTEXT") on $SHA"
